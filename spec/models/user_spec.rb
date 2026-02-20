require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:password) }
  end

  describe '#admin?' do
    context 'when admin is true' do
      let(:user) { build(:user, admin: true) }

      it 'returns true' do
        expect(user.admin?).to be true
      end
    end

    context 'when admin is false' do
      let(:user) { build(:user, admin: false) }

      it 'returns false' do
        expect(user.admin?).to be false
      end
    end
  end
end
