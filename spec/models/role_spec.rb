require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:ratings).with_foreign_key(:role_code).with_primary_key(:code) }
  end

  describe 'validations' do
    subject { build(:role) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
  end
end
