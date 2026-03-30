require "rails_helper"

RSpec.describe Episode, type: :model do
  describe "validations" do
    subject { build(:episode) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "status enum" do
    it "defines draft and published statuses" do
      expect(described_class.statuses).to eq("draft" => "draft", "published" => "published")
    end

    it "defaults to draft" do
      episode = described_class.new
      expect(episode.status).to eq("draft")
    end
  end

  describe "audio attachment" do
    it "can attach an audio file" do
      episode = create(:episode)
      episode.audio.attach(
        io: StringIO.new("fake audio"),
        filename: "episode.mp3",
        content_type: "audio/mpeg"
      )
      expect(episode.audio).to be_attached
    end
  end

  describe "image attachment" do
    it "can attach an image" do
      episode = create(:episode)
      episode.image.attach(
        io: StringIO.new("fake image"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )
      expect(episode.image).to be_attached
    end
  end

  describe "scopes" do
    describe ".published" do
      let!(:draft_episode) { create(:episode, status: "draft") }
      let!(:published_episode) { create(:episode, status: "published", published_at: Time.current) }

      it "returns only published episodes" do
        expect(described_class.published).to contain_exactly(published_episode)
      end
    end

    describe ".recent" do
      let!(:older) { create(:episode, status: "published", published_at: 2.days.ago) }
      let!(:newer) { create(:episode, status: "published", published_at: 1.day.ago) }
      let!(:draft) { create(:episode, status: "draft") }

      it "orders by published_at descending with nulls last" do
        expect(described_class.recent).to eq([ newer, older, draft ])
      end
    end
  end

  describe "duration_seconds validation" do
    it "allows nil duration" do
      episode = build(:episode, duration_seconds: nil)
      expect(episode).to be_valid
    end

    it "rejects negative duration" do
      episode = build(:episode, duration_seconds: -1)
      expect(episode).not_to be_valid
    end

    it "rejects non-integer duration" do
      episode = build(:episode, duration_seconds: 1.5)
      expect(episode).not_to be_valid
    end
  end

  describe "#formatted_duration" do
    it "returns nil when duration_seconds is nil" do
      episode = build(:episode, duration_seconds: nil)
      expect(episode.formatted_duration).to be_nil
    end

    it "formats seconds only" do
      episode = build(:episode, duration_seconds: 45)
      expect(episode.formatted_duration).to eq("0:45")
    end

    it "formats minutes and seconds" do
      episode = build(:episode, duration_seconds: 125)
      expect(episode.formatted_duration).to eq("2:05")
    end

    it "formats hours, minutes and seconds" do
      episode = build(:episode, duration_seconds: 3661)
      expect(episode.formatted_duration).to eq("1:01:01")
    end
  end

  describe "#extract_duration_from_audio" do
    let(:episode) { create(:episode) }

    context "when audio is attached" do
      before do
        episode.audio.attach(
          io: StringIO.new("fake audio content"),
          filename: "episode.mp3",
          content_type: "audio/mpeg"
        )
      end

      it "sets duration_seconds from audio metadata" do
        tag = instance_double(WahWah::Mp3Tag, duration: 125.7)
        allow(WahWah).to receive(:open).and_return(tag)

        episode.extract_duration_from_audio

        expect(episode.reload.duration_seconds).to eq(125)
      end

      it "does not overwrite manually set duration via guard" do
        episode.update_column(:duration_seconds, 999)
        allow(WahWah).to receive(:open)

        episode.extract_duration_from_audio

        expect(episode.reload.duration_seconds).to eq(999)
        expect(WahWah).not_to have_received(:open)
      end

      it "does not overwrite concurrently set duration via conditional update" do
        tag = instance_double(WahWah::Mp3Tag, duration: 125.7)
        allow(WahWah).to receive(:open).and_return(tag)

        # Simulate race: duration_seconds set in DB between guard and write
        episode.update_column(:duration_seconds, 999)

        episode.extract_duration_from_audio

        expect(episode.reload.duration_seconds).to eq(999)
      end

      it "only updates the specific episode, not other episodes" do
        other_episode = create(:episode)
        tag = instance_double(WahWah::Mp3Tag, duration: 125.7)
        allow(WahWah).to receive(:open).and_return(tag)

        episode.extract_duration_from_audio

        expect(episode.reload.duration_seconds).to eq(125)
        expect(other_episode.reload.duration_seconds).to be_nil
      end

      it "sets duration for exactly one second" do
        tag = instance_double(WahWah::Mp3Tag, duration: 1.0)
        allow(WahWah).to receive(:open).and_return(tag)

        episode.extract_duration_from_audio

        expect(episode.reload.duration_seconds).to eq(1)
      end

      it "handles audio files with zero duration" do
        tag = instance_double(WahWah::Mp3Tag, duration: 0.0)
        allow(WahWah).to receive(:open).and_return(tag)

        episode.extract_duration_from_audio

        expect(episode.reload.duration_seconds).to be_nil
      end

      it "handles wahwah errors gracefully" do
        allow(WahWah).to receive(:open).and_raise(WahWah::WahWahArgumentError)

        expect { episode.extract_duration_from_audio }.not_to raise_error
        expect(episode.reload.duration_seconds).to be_nil
      end
    end

    context "when audio is not attached" do
      it "does not attempt to read audio metadata" do
        allow(WahWah).to receive(:open)

        episode.extract_duration_from_audio

        expect(episode.reload.duration_seconds).to be_nil
        expect(WahWah).not_to have_received(:open)
      end
    end
  end

  describe "after_save_commit duration extraction" do
    let(:episode) { create(:episode) }

    it "enqueues extraction job when audio is attached and duration is nil" do
      expect {
        episode.audio.attach(
          io: StringIO.new("fake audio"),
          filename: "episode.mp3",
          content_type: "audio/mpeg"
        )
      }.to have_enqueued_job(ExtractEpisodeDurationJob).with(episode)
    end

    it "does not enqueue extraction job when duration is already set" do
      episode.update_column(:duration_seconds, 100)

      expect {
        episode.audio.attach(
          io: StringIO.new("fake audio"),
          filename: "episode.mp3",
          content_type: "audio/mpeg"
        )
      }.not_to have_enqueued_job(ExtractEpisodeDurationJob)
    end

    it "does not enqueue extraction job when no audio is attached" do
      expect {
        episode.update!(title: "Updated title")
      }.not_to have_enqueued_job(ExtractEpisodeDurationJob)
    end
  end

  describe "#publish!" do
    let(:episode) { create(:episode) }

    it "sets status to published" do
      episode.publish!
      expect(episode.status).to eq("published")
    end

    it "sets published_at" do
      episode.publish!
      expect(episode.published_at).to be_within(1.second).of(Time.current)
    end
  end
end
