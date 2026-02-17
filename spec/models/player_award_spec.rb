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
    it 'orders by position ascending' do
      player = create(:player)
      third = create(:player_award, player: player, position: 3)
      first = create(:player_award, player: player, position: 1)
      second = create(:player_award, player: player, position: 2)

      expect(described_class.ordered).to eq([first, second, third])
    end
  end
end
