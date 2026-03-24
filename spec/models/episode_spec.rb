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
