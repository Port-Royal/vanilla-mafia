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

      it "reports as parent" do
        expect(result.parent_view).to be true
      end

      describe "news" do
        let_it_be(:author) { create(:user) }
        let_it_be(:parent_news) { create(:news, :published, author: author, competition: parent) }
        let_it_be(:child_news) { create(:news, :published, author: author, competition: child1) }
        let_it_be(:draft_parent_news) { create(:news, author: author, competition: parent) }
        let_it_be(:other_news) { create(:news, :published, author: author, competition: other_comp) }

        it "includes published news linked directly to the parent competition" do
          expect(result.news).to include(parent_news)
        end

        it "excludes news linked to child competitions" do
          expect(result.news).not_to include(child_news)
        end

        it "excludes draft news" do
          expect(result.news).not_to include(draft_parent_news)
        end

        it "excludes news linked to unrelated competitions" do
          expect(result.news).not_to include(other_news)
        end
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

    describe "child winners" do
      let_it_be(:season) { create(:competition, :season) }
      let_it_be(:finished_child) do
        create(:competition, :series, parent: season, position: 1, started_on: Date.new(2026, 9, 1), ended_on: Date.new(2026, 9, 30))
      end
      let_it_be(:running_child) { create(:competition, :series, parent: season, position: 2, started_on: Date.new(2026, 10, 1)) }
      # Created last but placed first, so an unordered query would list it last.
      let_it_be(:empty_finished_child) do
        create(:competition, :series, parent: season, position: 0, ended_on: Date.new(2026, 10, 15))
      end
      let_it_be(:finished_game) { create(:game, competition: finished_child, game_number: 1) }
      let_it_be(:running_game) { create(:game, competition: running_child, game_number: 2) }
      # The runner-up is created first, so an unranked query would return it ahead of the winner.
      let_it_be(:runner_up) { create(:player, name: "Runner-up") }
      let_it_be(:winner) { create(:player, name: "Winner") }

      before_all do
        create(:game_participation, game: finished_game, player: runner_up, plus: 1.0)
        create(:game_participation, game: finished_game, player: winner, plus: 3.0)
        create(:game_participation, game: running_game, player: runner_up, plus: 5.0)
      end

      let(:service) { described_class.new(season) }
      let(:child_winners) { service.child_winners }
      let(:sql) { [] }
      let(:record_sql) { ->(*, payload) { sql << payload[:sql] } }
      let(:standings_queries) { sql.count { |query| query.include?("wins_count") } }

      it "maps every child in order" do
        expect(child_winners.keys).to eq([ empty_finished_child, finished_child, running_child ])
      end

      it "maps a finished child to the top of its standings" do
        expect(child_winners[finished_child]).to eq(winner)
      end

      it "maps a running child to nil" do
        expect(child_winners[running_child]).to be_nil
      end

      it "maps a finished child without participations to nil" do
        expect(child_winners[empty_finished_child]).to be_nil
      end

      context "when the service is only called" do
        before { ActiveSupport::Notifications.subscribed(record_sql, "sql.active_record") { service.call } }

        # The parent's standings stay a relation for the view to load, so no standings query runs here at all.
        it "runs no winner query" do
          expect(standings_queries).to eq(0)
        end

        # The children, the subtree ids and the games.
        it { expect(sql.size).to eq(3) }
      end

      context "when the winners are asked for" do
        before do
          service.call
          ActiveSupport::Notifications.subscribed(record_sql, "sql.active_record") { service.child_winners }
        end

        it "runs one standings query per finished child" do
          expect(standings_queries).to eq(2)
        end

        it "does not reload the subtree" do
          expect(sql.grep(/WITH RECURSIVE/)).to be_empty
        end

        # The subtree's links and the two finished children's standings; the children are not reloaded.
        it { expect(sql.size).to eq(3) }
      end

      context "when a finished child's games are in its own children" do
        let_it_be(:nested_season) { create(:competition, :season) }
        let_it_be(:stage) { create(:competition, :round, parent: nested_season, ended_on: Date.new(2026, 9, 30)) }
        let_it_be(:group) { create(:competition, :group, parent: stage) }
        let_it_be(:subgroup) { create(:competition, :group, parent: group) }
        let_it_be(:group_game) { create(:game, competition: subgroup, game_number: 1) }
        let_it_be(:sibling_stage) { create(:competition, :round, parent: nested_season, ended_on: Date.new(2026, 10, 30)) }
        let_it_be(:sibling_game) { create(:game, competition: sibling_stage, game_number: 2) }

        let(:service) { described_class.new(nested_season) }

        before_all do
          create(:game_participation, game: group_game, player: winner, plus: 2.0)
          create(:game_participation, game: sibling_game, player: runner_up, plus: 9.0)
        end

        let(:links_queries) { sql.grep(/SELECT "competitions"."parent_id", "competitions"."id"/) }

        before { ActiveSupport::Notifications.subscribed(record_sql, "sql.active_record") { child_winners } }

        it { expect(child_winners[stage]).to eq(winner) }
        it { expect(child_winners[sibling_stage]).to eq(runner_up) }
        it { expect(links_queries.size).to eq(1) }
        it { expect(links_queries.first).to include(%("competitions"."id" IN)) }
      end

      context "when the competition is a leaf" do
        let(:service) { described_class.new(finished_child) }

        it { expect(child_winners).to eq({}) }
      end
    end

    context "when competition has no games" do
      let_it_be(:empty_parent) { create(:competition, :season) }
      let_it_be(:empty_child) { create(:competition, :series, parent: empty_parent) }

      it "returns empty data for parent" do
        result = described_class.call(competition: empty_parent)

        expect(result.games_by_child.values.flatten).to be_empty
        expect(result.players).to be_empty
      end

      it "returns empty data for leaf" do
        leaf = create(:competition, :series)
        result = described_class.call(competition: leaf)

        expect(result.games).to be_empty
        expect(result.participations_by_player).to be_empty
        expect(result.players_sorted).to be_empty
      end
    end
  end
end
