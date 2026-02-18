require 'rails_helper'

RSpec.describe SeasonsHelper, type: :helper do
  describe '#win_percentage' do
    it 'calculates the percentage of wins' do
      player = double(games_count: 10, wins_count: 7)

      expect(helper.win_percentage(player)).to eq(70.0)
    end

    it 'returns 0 when games_count is zero' do
      player = double(games_count: 0)

      expect(helper.win_percentage(player)).to eq(0)
    end

    it 'rounds to one decimal place' do
      player = double(games_count: 3, wins_count: 1)

      expect(helper.win_percentage(player)).to eq(33.3)
    end

    it 'returns 100.0 when all games are wins' do
      player = double(games_count: 5, wins_count: 5)

      expect(helper.win_percentage(player)).to eq(100.0)
    end
  end
end
