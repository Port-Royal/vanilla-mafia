require 'rails_helper'

RSpec.describe PlayerAward, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:award) }
    it { is_expected.to belong_to(:competition).optional }
  end

  describe 'validations' do
    subject { build(:player_award, competition: create(:competition, :season)) }

    it { is_expected.to validate_uniqueness_of(:award_id).scoped_to(:player_id, :competition_id) }

    it 'allows same award for same player in different competitions' do
      comp_a = create(:competition, :season)
      comp_b = create(:competition, :season)
      player = create(:player)
      award = create(:award)
      create(:player_award, player: player, award: award, competition: comp_a)
      dup = build(:player_award, player: player, award: award, competition: comp_b)
      expect(dup).to be_valid
    end

    it 'rejects duplicate award for same player in same competition' do
      comp = create(:competition, :season)
      player = create(:player)
      award = create(:award)
      create(:player_award, player: player, award: award, competition: comp)
      dup = build(:player_award, player: player, award: award, competition: comp)
      expect(dup).not_to be_valid
    end
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
