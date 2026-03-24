require "rails_helper"

RSpec.describe Grant, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:user_grants).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:user_grants) }
  end

  describe "validations" do
    subject { build(:grant) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_inclusion_of(:code).in_array(Grant::CODES) }
    it { is_expected.to validate_uniqueness_of(:code) }
  end

  describe "CODES" do
    it "includes all expected grant codes" do
      expect(Grant::CODES).to contain_exactly("user", "judge", "editor", "admin")
    end
  end
end
