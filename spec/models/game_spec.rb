require 'rails_helper'

RSpec.describe Game, type: :model do
  describe '#full_name' do
    it 'includes all parts when all fields are present' do
      game = build(:game, played_on: Date.new(2026, 1, 15), season: 1, series: 2, game_number: 3, name: "Финал")

      expect(game.full_name).to eq("2026-01-15 Сезон 1 Серия 2 Игра 3 Финал")
    end

    it 'omits played_on when nil' do
      game = build(:game, played_on: nil, season: 1, series: 2, game_number: 3, name: "Финал")

      expect(game.full_name).to eq("Сезон 1 Серия 2 Игра 3 Финал")
    end

    it 'omits name when nil' do
      game = build(:game, played_on: Date.new(2026, 1, 15), season: 1, series: 2, game_number: 3, name: nil)

      expect(game.full_name).to eq("2026-01-15 Сезон 1 Серия 2 Игра 3")
    end
  end

  describe '#in_season_name' do
    it 'returns series and game number' do
      game = build(:game, series: 3, game_number: 5)

      expect(game.in_season_name).to eq("Серия 3 Игра 5")
    end
  end
end
