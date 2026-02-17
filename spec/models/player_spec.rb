require 'rails_helper'

RSpec.describe Player, type: :model do
  describe '.with_stats_for_season' do
    it 'returns games_count, wins_count, and total_rating for the given season' do
      player = create(:player)
      game1 = create(:game, season: 1, series: 1, game_number: 1)
      game2 = create(:game, season: 1, series: 1, game_number: 2)
      create(:rating, player: player, game: game1, plus: 3, minus: 1, win: true)
      create(:rating, player: player, game: game2, plus: 2, minus: 0, win: false)

      result = Player.with_stats_for_season(1).find(player.id)

      expect(result.games_count).to eq(2)
      expect(result.wins_count).to eq(1)
      expect(result.total_rating).to eq(4)
    end

    it 'excludes games from other seasons' do
      player = create(:player)
      game_s1 = create(:game, season: 1, series: 1, game_number: 1)
      game_s2 = create(:game, season: 2, series: 1, game_number: 1)
      create(:rating, player: player, game: game_s1, plus: 5, minus: 0, win: true)
      create(:rating, player: player, game: game_s2, plus: 10, minus: 0, win: true)

      result = Player.with_stats_for_season(1).find(player.id)

      expect(result.games_count).to eq(1)
      expect(result.total_rating).to eq(5)
    end

    it 'handles nil plus/minus with COALESCE' do
      player = create(:player)
      game = create(:game, season: 1, series: 1, game_number: 1)
      create(:rating, player: player, game: game, plus: nil, minus: nil, win: false)

      result = Player.with_stats_for_season(1).find(player.id)

      expect(result.total_rating).to eq(0)
    end
  end
end
