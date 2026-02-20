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
    let_it_be(:player_award) { create(:award, staff: false) }
    let_it_be(:staff_award) { create(:award, staff: true) }

    it 'returns awards where staff is false' do
      expect(described_class.for_players).to include(player_award)
      expect(described_class.for_players).not_to include(staff_award)
    end
  end

  describe '.for_staff' do
    let_it_be(:player_award) { create(:award, staff: false) }
    let_it_be(:staff_award) { create(:award, staff: true) }

    it 'returns awards where staff is true' do
      expect(described_class.for_staff).to include(staff_award)
      expect(described_class.for_staff).not_to include(player_award)
    end
  end

  describe '.ordered' do
    let_it_be(:third) { create(:award, position: 3) }
    let_it_be(:first) { create(:award, position: 1) }
    let_it_be(:second) { create(:award, position: 2) }

    it 'orders by position ascending' do
      expect(described_class.ordered).to eq([ first, second, third ])
    end
  end
end
