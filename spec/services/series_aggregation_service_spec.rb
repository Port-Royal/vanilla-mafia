require "rails_helper"

RSpec.describe SeriesAggregationService do
  describe ".call" do
    let!(:game2) { create(:game, season: 5, series: 1, game_number: 2) }
    let!(:game1) { create(:game, season: 5, series: 1, game_number: 1) }
    let!(:other_series_game) { create(:game, season: 5, series: 2, game_number: 1) }
    let!(:other_season_game) { create(:game, season: 6, series: 1, game_number: 1) }
    let!(:player1) { create(:player, name: "Алексей") }
    let!(:player2) { create(:player, name: "Борис") }
    let!(:rating1) { create(:rating, game: game1, player: player1, plus: 3.0, minus: 0.5) }
    let!(:rating2) { create(:rating, game: game1, player: player2, plus: 1.0, minus: 1.5) }
    let!(:rating3) { create(:rating, game: game2, player: player1, plus: 2.0, minus: 1.0) }
    let!(:rating4) { create(:rating, game: game2, player: player2, plus: 5.0, minus: 0.0) }
    let!(:other_season_rating) { create(:rating, game: other_season_game, player: player1, plus: 10.0, minus: 0.0) }
    let(:result) { described_class.call(season: 5, series: 1) }

    it "returns a Result" do
      expect(result).to be_a(described_class::Result)
    end

    it "returns games ordered by game_number" do
      expect(result.games).to eq([ game1, game2 ])
    end

    it "excludes games from other series" do
      expect(result.games).not_to include(other_series_game)
    end

    it "excludes games from other seasons" do
      expect(result.games).not_to include(other_season_game)
    end

    it "groups ratings by player" do
      expect(result.ratings_by_player.keys).to contain_exactly(player1, player2)
    end

    it "includes all ratings for each player" do
      expect(result.ratings_by_player[player1]).to contain_exactly(rating1, rating3)
      expect(result.ratings_by_player[player2]).to contain_exactly(rating2, rating4)
    end

    it "eager loads player association on ratings" do
      first_rating = result.ratings_by_player.values.first.first
      expect(first_rating.association(:player)).to be_loaded
    end

    it "sorts players by total rating descending" do
      # player2 total: (1.0 - 1.5) + (5.0 - 0.0) = 4.5
      # player1 total: (3.0 - 0.5) + (2.0 - 1.0) = 3.5
      expect(result.players_sorted).to eq([ player2, player1 ])
    end

    context "when players have equal totals" do
      let!(:rating1) { create(:rating, game: game1, player: player2, plus: 2.0, minus: 0.0) }
      let!(:rating2) { create(:rating, game: game1, player: player1, plus: 0.0, minus: 0.0) }
      let!(:rating3) { create(:rating, game: game2, player: player2, plus: 0.0, minus: 0.0) }
      let!(:rating4) { create(:rating, game: game2, player: player1, plus: 2.0, minus: 0.0) }
      let!(:other_season_rating) { create(:rating, game: other_season_game, player: player1) }

      it "breaks ties by player id ascending" do
        expect(result.players_sorted).to eq([ player1, player2 ])
      end
    end

    context "when series has no games" do
      let(:empty_result) { described_class.call(season: 99, series: 99) }

      it "returns empty games" do
        expect(empty_result.games).to be_empty
      end

      it "returns empty ratings_by_player" do
        expect(empty_result.ratings_by_player).to be_empty
      end

      it "returns empty players_sorted" do
        expect(empty_result.players_sorted).to be_empty
      end
    end
  end
end
