require 'rails_helper'

RSpec.describe Award, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:player_awards).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:players).through(:player_awards) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
  end

  describe '.for_players' do
    it 'returns awards where staff is false' do
      player_award = create(:award, staff: false)
      staff_award = create(:award, staff: true)

      expect(described_class.for_players).to include(player_award)
      expect(described_class.for_players).not_to include(staff_award)
    end
  end

  describe '.for_staff' do
    it 'returns awards where staff is true' do
      player_award = create(:award, staff: false)
      staff_award = create(:award, staff: true)

      expect(described_class.for_staff).to include(staff_award)
      expect(described_class.for_staff).not_to include(player_award)
    end
  end

  describe '.ordered' do
    it 'orders by position ascending' do
      third = create(:award, position: 3)
      first = create(:award, position: 1)
      second = create(:award, position: 2)

      expect(described_class.ordered).to eq([ first, second, third ])
    end
  end
end
