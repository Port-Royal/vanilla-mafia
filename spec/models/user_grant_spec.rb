require "rails_helper"

RSpec.describe UserGrant, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:grant) }
  end

  describe "validations" do
    it "validates uniqueness of grant scoped to user" do
      grant = create(:grant, code: "judge")
      user = create(:user)
      create(:user_grant, user: user, grant: grant)
      duplicate = build(:user_grant, user: user, grant: grant)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.where(:grant_id, :taken)).to be_present
    end

    it "allows same grant for different users" do
      grant = create(:grant, code: "judge")
      create(:user_grant, grant: grant)
      user_grant = build(:user_grant, grant: grant)

      expect(user_grant).to be_valid
    end
  end

  describe "after_destroy callback" do
    context "when subscriber grant is removed" do
      let(:user) { create(:user) }
      let(:subscriber_grant) { Grant.find_or_create_by!(code: "subscriber") }
      let!(:user_grant) { create(:user_grant, user: user, grant: subscriber_grant) }
      let!(:feed_token) { create(:podcast_feed_token, user: user) }

      it "revokes the user's podcast feed token" do
        user_grant.destroy!
        expect(feed_token.reload.revoked?).to be true
      end
    end

    context "when subscriber grant is removed and user has no feed token" do
      let(:user) { create(:user) }
      let(:subscriber_grant) { Grant.find_or_create_by!(code: "subscriber") }
      let!(:user_grant) { create(:user_grant, user: user, grant: subscriber_grant) }

      it "does not raise an error" do
        expect { user_grant.destroy! }.not_to raise_error
      end
    end

    context "when non-subscriber grant is removed" do
      let(:user) { create(:user) }
      let(:judge_grant) { Grant.find_or_create_by!(code: "judge") }
      let!(:user_grant) { create(:user_grant, user: user, grant: judge_grant) }
      let!(:feed_token) { create(:podcast_feed_token, user: user) }

      it "does not revoke the user's podcast feed token" do
        user_grant.destroy!
        expect(feed_token.reload.revoked?).to be false
      end
    end
  end
end
