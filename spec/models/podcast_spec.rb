require "rails_helper"

RSpec.describe Podcast, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:author) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:language) }
  end

  describe ".instance" do
    it "creates a record on first call" do
      expect { Podcast.instance }.to change(Podcast, :count).from(0).to(1)
    end

    it "returns the same record on subsequent calls" do
      first = Podcast.instance
      second = Podcast.instance
      expect(second).to eq(first)
    end

    it "sets default attributes" do
      podcast = Podcast.instance
      expect(podcast).to have_attributes(
        title: "Vanilla Mafia",
        author: "Vanilla Mafia",
        description: "Подкаст клуба спортивной мафии Vanilla Mafia",
        language: "ru"
      )
    end
  end

  describe "cover attachment" do
    let(:podcast) { Podcast.instance }

    it "can attach a cover image" do
      podcast.cover.attach(io: StringIO.new("fake"), filename: "cover.jpg", content_type: "image/jpeg")
      expect(podcast.cover).to be_attached
    end

    context "with an allowed content type" do
      before do
        podcast.cover.attach(io: StringIO.new("c"), filename: "c.png", content_type: "image/png")
      end

      it "is valid" do
        expect(podcast).to be_valid
      end
    end

    context "with a disallowed content type" do
      before do
        podcast.cover.attach(io: StringIO.new("c"), filename: "c.gif", content_type: "image/gif")
      end

      it "is invalid" do
        expect(podcast).not_to be_valid
        expect(podcast.errors[:cover]).to include(I18n.t("errors.messages.content_type"))
      end
    end

    context "when over the size limit" do
      before do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("x"),
          filename: "big.jpg",
          content_type: "image/jpeg"
        )
        blob.update_columns(byte_size: Podcast::MAX_COVER_SIZE + 1)
        podcast.cover.attach(blob)
      end

      it "is invalid" do
        expect(podcast).not_to be_valid
        expect(podcast.errors[:cover]).to include(
          I18n.t("errors.messages.file_size", count: Podcast::MAX_COVER_SIZE / 1.megabyte)
        )
      end
    end
  end
end
