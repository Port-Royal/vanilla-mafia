require 'rails_helper'

RSpec.describe PlayerAward, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:award) }
  end

  describe 'validations' do
    subject { build(:player_award) }

    it { is_expected.to validate_uniqueness_of(:award_id).scoped_to(:player_id, :season) }
  end

  describe '.ordered' do
    let_it_be(:player) { create(:player) }
    let_it_be(:third) { create(:player_award, player: player, position: 3) }
    let_it_be(:first) { create(:player_award, player: player, position: 1) }
    let_it_be(:second) { create(:player_award, player: player, position: 2) }

    it 'orders by position ascending' do
      expect(described_class.ordered).to eq([ first, second, third ])
    end
  end
end
