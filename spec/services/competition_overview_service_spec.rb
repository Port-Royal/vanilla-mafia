require "rails_helper"

RSpec.describe CompetitionOverviewService do
  describe ".call" do
    context "when competition is a parent (has children)" do
      let_it_be(:parent) { create(:competition, :season) }
      let_it_be(:child1) { create(:competition, :series, parent: parent, position: 1) }
      let_it_be(:child2) { create(:competition, :series, parent: parent, position: 2) }
      let_it_be(:game1) { create(:game, competition: child1, game_number: 1) }
      let_it_be(:game2) { create(:game, competition: child1, game_number: 2) }
      let_it_be(:game3) { create(:game, competition: child2, game_number: 1) }
      let_it_be(:other_comp) { create(:competition, :series) }
      let_it_be(:other_game) { create(:game, competition: other_comp, game_number: 1) }
      let_it_be(:player1) { create(:player, name: "Алексей") }
      let_it_be(:player2) { create(:player, name: "Борис") }

      before do
        create(:game_participation, game: game1, player: player1, plus: 3.0, minus: 0.5, win: true)
        create(:game_participation, game: game1, player: player2, plus: 1.0, minus: 1.5, win: false)
      end

      let(:result) { described_class.call(competition: parent) }

      it "returns a Result" do
        expect(result).to be_a(described_class::Result)
      end

      it "groups games by child competition ordered by position" do
        expect(result.games_by_child.keys).to eq([ child1, child2 ])
      end

      it "orders games within each child" do
        expect(result.games_by_child[child1]).to eq([ game1, game2 ])
      end

      it "returns empty defaults for leaf-only fields" do
        expect(result.games).to be_empty
        expect(result.participations_by_player).to eq({})
        expect(result.players_sorted).to eq([])
      end

      it "excludes games from other competitions" do
        all_games = result.games_by_child.values.flatten
        expect(all_games).not_to include(other_game)
      end

      it "returns players ranked by total rating" do
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

      it "returns the player count" do
        expect(result.player_count).to eq(2)
      end

      it "reports as parent" do
        expect(result.parent_view).to be true
      end
    end

    context "when competition is a leaf (no children)" do
      let_it_be(:competition) { create(:competition, :series) }
      let_it_be(:game1) { create(:game, competition: competition, game_number: 1) }
      let_it_be(:game2) { create(:game, competition: competition, game_number: 2) }
      let_it_be(:player1) { create(:player, name: "Виктор") }
      let_it_be(:player2) { create(:player, name: "Галина") }
      let!(:participation1) { create(:game_participation, game: game1, player: player1, plus: 3.0, minus: 0.5) }
      let!(:participation2) { create(:game_participation, game: game1, player: player2, plus: 1.0, minus: 1.5) }
      let!(:participation3) { create(:game_participation, game: game2, player: player1, plus: 2.0, minus: 1.0) }
      let!(:participation4) { create(:game_participation, game: game2, player: player2, plus: 5.0, minus: 0.0) }

      let(:result) { described_class.call(competition: competition) }

      it "returns ordered games directly" do
        expect(result.games).to eq([ game1, game2 ])
      end

      it "groups participations by player" do
        expect(result.participations_by_player.keys).to contain_exactly(player1, player2)
      end

      it "includes all participations for each player" do
        expect(result.participations_by_player[player1]).to contain_exactly(participation1, participation3)
        expect(result.participations_by_player[player2]).to contain_exactly(participation2, participation4)
      end

      it "returns the player count" do
        expect(result.player_count).to eq(2)
      end

      it "sorts players by total rating descending" do
        expect(result.players_sorted).to eq([ player2, player1 ])
      end

      it "breaks ties by player id ascending" do
        participation1.update!(plus: 2.0, minus: 0.0)
        participation2.update!(plus: 0.0, minus: 0.0)
        participation3.update!(plus: 0.0, minus: 0.0)
        participation4.update!(plus: 2.0, minus: 0.0)

        expect(result.players_sorted).to eq([ player1, player2 ])
      end

      it "reports as not parent" do
        expect(result.parent_view).to be false
      end
    end

    context "when competition has no games" do
      let_it_be(:empty_parent) { create(:competition, :season) }
      let_it_be(:empty_child) { create(:competition, :series, parent: empty_parent) }

      it "returns empty data for parent" do
        result = described_class.call(competition: empty_parent)

        expect(result.games_by_child.values.flatten).to be_empty
        expect(result.players).to be_empty
        expect(result.player_count).to eq(0)
      end

      it "returns empty data for leaf" do
        leaf = create(:competition, :series)
        result = described_class.call(competition: leaf)

        expect(result.games).to be_empty
        expect(result.participations_by_player).to be_empty
        expect(result.players_sorted).to be_empty
        expect(result.player_count).to eq(0)
      end
    end
  end
end
