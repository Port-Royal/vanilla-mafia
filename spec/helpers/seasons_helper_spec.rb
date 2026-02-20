require 'rails_helper'

RSpec.describe SeasonsHelper, type: :helper do
  describe '#win_percentage' do
    context 'when player has wins' do
      let(:player) { double(games_count: 10, wins_count: 7) }

      it 'calculates the percentage of wins' do
        expect(helper.win_percentage(player)).to eq(70.0)
      end
    end

    context 'when games_count is zero' do
      let(:player) { double(games_count: 0) }

      it 'returns 0' do
        expect(helper.win_percentage(player)).to eq(0)
      end
    end

    context 'when result needs rounding' do
      let(:player) { double(games_count: 3, wins_count: 1) }

      it 'rounds to one decimal place' do
        expect(helper.win_percentage(player)).to eq(33.3)
      end
    end

    context 'when all games are wins' do
      let(:player) { double(games_count: 5, wins_count: 5) }

      it 'returns 100.0' do
        expect(helper.win_percentage(player)).to eq(100.0)
      end
    end
  end
end
