require "rails_helper"

RSpec.describe SeasonOverviewService do
  describe ".call" do
    let_it_be(:game2) { create(:game, season: 5, series: 1, game_number: 2) }
    let_it_be(:game1) { create(:game, season: 5, series: 1, game_number: 1) }
    let_it_be(:game3) { create(:game, season: 5, series: 2, game_number: 1) }
    let_it_be(:other_season_game) { create(:game, season: 6, series: 1, game_number: 1) }
    let_it_be(:player2) { create(:player, name: "Борис") }
    let_it_be(:player1) { create(:player, name: "Алексей") }
    let_it_be(:rating1) { create(:rating, game: game1, player: player1, plus: 3.0, minus: 0.5, win: true) }
    let_it_be(:rating2) { create(:rating, game: game1, player: player2, plus: 1.0, minus: 1.5, win: false) }
    let(:result) { described_class.call(season: 5) }

    it "returns a Result" do
      expect(result).to be_a(described_class::Result)
    end

    it "groups games by series" do
      expect(result.games_by_series.keys).to contain_exactly(1, 2)
    end

    it "orders games within each series" do
      expect(result.games_by_series[1]).to eq([ game1, game2 ])
    end

    it "excludes games from other seasons" do
      all_games = result.games_by_series.values.flatten
      expect(all_games).not_to include(other_season_game)
    end

    it "returns players ranked by total rating descending" do
      expect(result.players).to eq([ player1, player2 ])
    end

    it "computes games_count for players" do
      player = result.players.find { |p| p.id == player1.id }
      expect(player.games_count).to eq(1)
    end

    it "computes wins_count for players" do
      player = result.players.find { |p| p.id == player1.id }
      expect(player.wins_count).to eq(1)
    end

    it "computes total_rating for players" do
      player = result.players.find { |p| p.id == player1.id }
      expect(player.total_rating).to eq(2.5)
    end

    it "returns the player count for the season" do
      expect(result.player_count).to eq(2)
    end

    context "when season has no games" do
      let(:empty_result) { described_class.call(season: 99) }

      it "returns empty games_by_series" do
        expect(empty_result.games_by_series).to be_empty
      end

      it "returns empty players" do
        expect(empty_result.players).to be_empty
      end

      it "returns zero player count" do
        expect(empty_result.player_count).to eq(0)
      end
    end
  end
end
