require "rails_helper"

RSpec.describe CompetitionRanking do
  describe ".call" do
    subject(:entries) { described_class.call(competition) }

    context "when the competition has children" do
      let_it_be(:competition) { create(:competition, :season) }
      let_it_be(:series) { create(:competition, :series, parent: competition) }
      let_it_be(:round) { create(:competition, :round, parent: series) }
      let_it_be(:series_game) { create(:game, competition: series, game_number: 1) }
      let_it_be(:round_game) { create(:game, competition: round, game_number: 2) }
      let_it_be(:boris) { create(:player, name: "Борис") }
      let_it_be(:anna) { create(:player, name: "Анна") }
      let_it_be(:vera) { create(:player, name: "Вера") }
      let_it_be(:outsider) { create(:player, name: "Чужой") }
      let_it_be(:other_game) { create(:game, competition: create(:competition, :series)) }

      before_all do
        create(:game_participation, game: other_game, player: outsider, plus: 10)
        create(:game_participation, game: series_game, player: boris, plus: 2, win: true)
        create(:game_participation, game: series_game, player: anna, plus: 1, win: false)
        create(:game_participation, game: round_game, player: anna, plus: 1, win: true)
        create(:game_participation, game: round_game, player: vera, plus: 2, win: false)
      end

      it "orders players like the competition page rating" do
        expected = Player.with_aggregated_stats.where(games: { competition_id: competition.subtree_ids }).ranked.map(&:id)
        expect(entries.map(&:player_id)).to eq(expected)
      end

      it "leaves out players of other competitions" do
        expect(entries.map(&:player_id)).not_to include(outsider.id)
      end

      it "breaks a rating tie by wins, then games, then name" do
        expect(entries.map(&:player_id)).to eq([ anna.id, boris.id, vera.id ])
      end

      it "counts games of grandchildren" do
        expect(entries.first).to have_attributes(games: 2, wins: 1, rating: 2)
      end
    end

    context "when the competition has no children" do
      let_it_be(:competition) { create(:competition, :series) }
      let_it_be(:other_competition) { create(:competition, :series) }
      let_it_be(:first_game) { create(:game, competition: competition, game_number: 1) }
      let_it_be(:second_game) { create(:game, competition: competition, game_number: 2) }
      let_it_be(:other_game) { create(:game, competition: other_competition, game_number: 1) }
      let_it_be(:lower_id) { create(:player) }
      let_it_be(:higher_id) { create(:player) }
      let_it_be(:leader) { create(:player) }

      before_all do
        # The higher id plays first, so a tie kept in play order would put it first.
        create(:game_participation, game: first_game, player: higher_id, plus: 1, win: true)
        create(:game_participation, game: first_game, player: lower_id, plus: 1)
        create(:game_participation, game: first_game, player: leader, plus: 2, minus: 0.5, win: true)
        create(:game_participation, game: second_game, player: leader, plus: 1, best_move: 0.25)
        create(:game_participation, game: other_game, player: lower_id, plus: 10)
      end

      it "orders by total, then by player id" do
        expect(entries.map(&:player_id)).to eq([ leader.id, lower_id.id, higher_id.id ])
      end

      it "sums the player's games, wins and totals in this competition only" do
        expect(entries.first).to have_attributes(games: 2, wins: 1, rating: BigDecimal("2.75"))
      end

      it "counts only this competition's games for other players" do
        expect(entries.find { |entry| entry.player_id == lower_id.id }).to have_attributes(games: 1, rating: 1)
      end
    end

    context "when the competition has no games" do
      let_it_be(:competition) { create(:competition, :series) }

      it { is_expected.to eq([]) }
    end
  end

  describe ".leaf_sort_key" do
    let(:keys) { [ [ 2, 1 ], [ 1, 5 ], [ 3, 5 ] ].map { |id, total| described_class.leaf_sort_key(id, total) } }

    it "puts the higher total first, then the lower player id" do
      expect(keys.sort).to eq([ [ -5, 1 ], [ -5, 3 ], [ -1, 2 ] ])
    end
  end
end
