require "rails_helper"

RSpec.describe PodcastFeedToken, type: :model do
  describe "validations" do
    subject { build(:podcast_feed_token) }

    it { is_expected.to validate_uniqueness_of(:user_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "token generation" do
    it "generates a token on create" do
      token = create(:podcast_feed_token)
      expect(token.token).to be_present
      expect(token.token.length).to be >= 24
    end

    it "generates unique tokens" do
      token1 = create(:podcast_feed_token)
      token2 = create(:podcast_feed_token)
      expect(token1.token).not_to eq(token2.token)
    end
  end

  describe "#revoke!" do
    let(:token) { create(:podcast_feed_token) }

    it "sets revoked_at to current time" do
      token.revoke!
      expect(token.revoked_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "#revoked?" do
    let(:token) { create(:podcast_feed_token) }

    context "when not revoked" do
      it "returns false" do
        expect(token.revoked?).to be(false)
      end
    end

    context "when revoked" do
      before { token.revoke! }

      it "returns true" do
        expect(token.revoked?).to be(true)
      end
    end
  end

  describe ".active" do
    let!(:active_token) { create(:podcast_feed_token) }
    let!(:revoked_token) { create(:podcast_feed_token, revoked_at: 1.day.ago) }

    it "returns only non-revoked tokens" do
      expect(described_class.active).to eq([ active_token ])
    end
  end
end
