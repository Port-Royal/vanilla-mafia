require "rails_helper"
require_relative "../../db/migrate/20260315121205_add_competition_id_to_games"

RSpec.describe "AddCompetitionIdToGames migration", type: :model do
  describe "schema" do
    it "adds competition_id column to games" do
      column = Game.column_for_attribute(:competition_id)
      expect(column.type).to eq(:integer)
      expect(column.null).to be true
    end

    it "has an index on competition_id" do
      expect(ActiveRecord::Base.connection.index_exists?(:games, :competition_id)).to be true
    end

    it "has a foreign key to competitions" do
      foreign_keys = ActiveRecord::Base.connection.foreign_keys(:games)
      fk = foreign_keys.find { |fk| fk.column == "competition_id" }
      expect(fk).to be_present
      expect(fk.to_table).to eq("competitions")
    end
  end

  describe "backfill" do
    let_it_be(:season_comp) { create(:competition, :season, legacy_season: 1, legacy_series: nil) }
    let_it_be(:series_comp) { create(:competition, :series, legacy_season: 2, legacy_series: 3, parent: season_comp) }
    let_it_be(:game_with_match) { create(:game, season: 2, series: 3) }
    let_it_be(:game_without_match) { create(:game, season: 99, series: 99) }

    before_all do
      ActiveRecord::Base.connection.execute("UPDATE games SET competition_id = NULL")
      AddCompetitionIdToGames.new.backfill_competition_ids
    end

    it "links games to competitions by legacy_season and legacy_series" do
      expect(game_with_match.reload.competition_id).to eq(series_comp.id)
    end

    it "leaves competition_id nil for games with no matching competition" do
      expect(game_without_match.reload.competition_id).to be_nil
    end
  end
end
