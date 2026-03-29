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
  end

  describe "cover attachment" do
    it "can attach a cover image" do
      podcast = Podcast.instance
      podcast.cover.attach(io: StringIO.new("fake"), filename: "cover.jpg", content_type: "image/jpeg")
      expect(podcast.cover).to be_attached
    end
  end
end
