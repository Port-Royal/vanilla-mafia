# frozen_string_literal: true

require "rails_helper"
require_relative "../../db/migrate/20260328184252_backfill_game_participation_seats"

RSpec.describe BackfillGameParticipationSeats do
  let(:migration) { described_class.new }

  describe "#backfill_sql" do
    let_it_be(:game) { create(:game) }

    context "when all seats are nil" do
      let_it_be(:p1) { create(:game_participation, game: game, seat: nil) }
      let_it_be(:p2) { create(:game_participation, game: game, seat: nil) }
      let_it_be(:p3) { create(:game_participation, game: game, seat: nil) }

      before { ActiveRecord::Base.connection.execute(migration.backfill_sql) }

      it "assigns sequential seat numbers by id order" do
        expect([ p1, p2, p3 ].map { |p| p.reload.seat }).to eq([ 1, 2, 3 ])
      end
    end

    context "when seats are already populated" do
      let_it_be(:game2) { create(:game) }
      let_it_be(:seated) { create(:game_participation, game: game2, seat: 5) }

      before { ActiveRecord::Base.connection.execute(migration.backfill_sql) }

      it "does not overwrite existing seats" do
        expect(seated.reload.seat).to eq(5)
      end
    end

    context "with multiple games" do
      let_it_be(:game_a) { create(:game) }
      let_it_be(:game_b) { create(:game) }
      let_it_be(:a1) { create(:game_participation, game: game_a, seat: nil) }
      let_it_be(:a2) { create(:game_participation, game: game_a, seat: nil) }
      let_it_be(:b1) { create(:game_participation, game: game_b, seat: nil) }

      before { ActiveRecord::Base.connection.execute(migration.backfill_sql) }

      it "numbers seats independently per game" do
        expect([ a1, a2 ].map { |p| p.reload.seat }).to eq([ 1, 2 ])
        expect(b1.reload.seat).to eq(1)
      end
    end
  end
end
