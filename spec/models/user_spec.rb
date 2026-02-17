require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:password) }
  end

  describe '#admin?' do
    it 'returns true when admin is true' do
      user = build(:user, admin: true)

      expect(user.admin?).to be true
    end

    it 'returns false when admin is false' do
      user = build(:user, admin: false)

      expect(user.admin?).to be false
    end
  end
end
