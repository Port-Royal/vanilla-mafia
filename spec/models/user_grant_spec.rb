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
end
