require "rails_helper"

RSpec.describe ClubStatsService do
  describe ".totals" do
    subject(:totals) { described_class.totals }

    let_it_be(:season) { create(:competition, :season, ended_on: Date.new(2025, 2, 1)) }
    let_it_be(:running_season) { create(:competition, :season) }
    let_it_be(:finished_series) { create(:competition, :series, parent: season, ended_on: Date.new(2025, 1, 1)) }
    let_it_be(:players) { create_list(:player, 3) }
    let_it_be(:finished_games) { create_list(:game, 2, competition: finished_series, result: "peace_victory") }
    let_it_be(:game_in_progress) { create(:game, competition: finished_series) }

    it { expect(totals).to eq(players: 3, games: 2, competitions: 1) }
  end

  describe ".call" do
    subject(:result) { described_class.call }

    let(:rows) { result.competitions }
    let(:row_names) { rows.map { |row| row.competition.name } }

    context "without data" do
      it { expect(result.totals).to eq(players: 0, games: 0, competitions: 0) }
      it { expect(result.first_game_on).to be_nil }
      it { expect(result.results).to eq(peace_victory: 0, mafia_victory: 0, draw: 0) }
      it { expect(rows).to eq([]) }
    end

    context "with games" do
      let_it_be(:older) { create(:competition, :season, name: "Older", position: 1, ended_on: Date.new(2024, 6, 1)) }
      let_it_be(:newer) { create(:competition, :season, name: "Newer", position: 2) }
      let_it_be(:empty) { create(:competition, :season, name: "Empty", position: 3) }
      let_it_be(:unstarted) { create(:competition, :tournament, name: "Unstarted", position: 4) }
      let_it_be(:older_series) { create(:competition, :series, parent: older) }
      let_it_be(:older_stage) { create(:competition, :round, parent: older_series) }
      let_it_be(:newer_series) { create(:competition, :series, parent: newer) }
      let_it_be(:alice) { create(:player) }
      let_it_be(:bob) { create(:player) }
      let_it_be(:carol) { create(:player) }

      let_it_be(:older_games) do
        [
          create(:game, competition: older_series, result: "peace_victory", played_on: Date.new(2024, 1, 13)),
          create(:game, competition: older_stage, result: "mafia_victory", played_on: Date.new(2024, 2, 1)),
          create(:game, competition: older_stage, result: "draw", played_on: Date.new(2024, 2, 2))
        ]
      end
      let_it_be(:newer_games) do
        [
          create(:game, competition: newer_series, result: "mafia_victory", played_on: Date.new(2025, 1, 1)),
          create(:game, competition: newer_series, result: "mafia_victory", played_on: Date.new(2025, 1, 2))
        ]
      end
      let_it_be(:unstarted_game) { create(:game, competition: unstarted, played_on: Date.new(2023, 1, 1)) }

      let_it_be(:participations) do
        [
          create(:game_participation, game: older_games[0], player: alice),
          create(:game_participation, game: older_games[1], player: alice),
          create(:game_participation, game: older_games[2], player: bob),
          create(:game_participation, game: newer_games[0], player: alice),
          create(:game_participation, game: newer_games[1], player: alice),
          create(:game_participation, game: unstarted_game, player: carol)
        ]
      end

      let(:older_row) { rows.find { |row| row.competition == older } }
      let(:newer_row) { rows.find { |row| row.competition == newer } }

      it { expect(result.totals).to eq(players: 3, games: 5, competitions: 1) }
      it { expect(result.first_game_on).to eq(Date.new(2024, 1, 13)) }
      it { expect(result.results).to eq(peace_victory: 1, mafia_victory: 3, draw: 1) }

      it "lists the roots with finished games, newest first" do
        expect(row_names).to eq(%w[Newer Older])
      end

      it "counts a root's whole subtree" do
        expect(older_row).to have_attributes(games_count: 3, peace_wins: 1, mafia_wins: 1)
      end

      it { expect(newer_row).to have_attributes(games_count: 2, peace_wins: 0, mafia_wins: 2) }

      it "counts each player once per root" do
        expect([ older_row.players_count, newer_row.players_count ]).to eq([ 2, 1 ])
      end

      context "when two roots share a position" do
        let_it_be(:twin) { create(:competition, :season, name: "Twin", position: 2) }
        let_it_be(:twin_game) { create(:game, competition: twin, result: "draw") }

        it "puts the later created first" do
          expect(row_names).to eq(%w[Twin Newer Older])
        end
      end

      context "when a root created later sits earlier in the admin's order" do
        let_it_be(:early) { create(:competition, :season, name: "Early", position: 0) }
        let_it_be(:early_game) { create(:game, competition: early, result: "draw") }

        it "follows the position, not the creation order" do
          expect(row_names).to eq(%w[Newer Older Early])
        end
      end

      context "when someone played only an unfinished game" do
        let_it_be(:dave) { create(:player) }
        let_it_be(:open_game) { create(:game, competition: newer_series) }
        let_it_be(:open_participation) { create(:game_participation, game: open_game, player: dave) }

        it { expect(newer_row.players_count).to eq(1) }
      end

      context "when a root has games but nobody took part" do
        let_it_be(:bare) { create(:competition, :season, name: "Bare", position: 5) }
        let_it_be(:bare_game) { create(:game, competition: bare, result: "draw") }

        it { expect(rows.first).to have_attributes(competition: bare, games_count: 1, players_count: 0) }
      end

      describe "queries" do
        let(:sql) { [] }
        let(:record_sql) { ->(*, payload) { sql << payload[:sql] unless payload[:name] == "SCHEMA" } }

        before { ActiveSupport::Notifications.subscribed(record_sql, "sql.active_record") { result } }

        # Three totals, the first game date, games by competition and result, the competition links, the
        # participants and the roots.
        it { expect(sql.size).to eq(8) }
      end
    end
  end
end
