require "rails_helper"

RSpec.describe UserRole, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:user_role) }

    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array(UserRole::ROLES) }

    it "validates uniqueness of role scoped to user" do
      user = create(:user)
      create(:user_role, user: user, role: "judge")
      duplicate = build(:user_role, user: user, role: "judge")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.where(:role, :taken)).to be_present
    end

    it "allows same role for different users" do
      create(:user_role, role: "judge")
      user_role = build(:user_role, role: "judge")

      expect(user_role).to be_valid
    end
  end

  describe "ROLES" do
    it "includes all expected roles" do
      expect(UserRole::ROLES).to contain_exactly("user", "judge", "editor", "admin")
    end
  end
end
