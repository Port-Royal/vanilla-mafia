require "rails_helper"
require_relative "../../db/migrate/20260315121205_add_competition_id_to_games"

RSpec.describe "AddCompetitionIdToGames migration" do
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
    let_it_be(:other_comp) { create(:competition, :series, legacy_season: 5, legacy_series: 1, parent: season_comp) }
    let_it_be(:game_with_match) { create(:game, season: 2, series: 3) }
    let_it_be(:game_without_match) { create(:game, season: 99, series: 99) }
    let_it_be(:game_already_linked) { create(:game, season: 5, series: 1) }

    before_all do
      ActiveRecord::Base.connection.execute(
        "UPDATE games SET competition_id = #{other_comp.id} WHERE id = #{game_already_linked.id}"
      )
      ids = [ game_with_match.id, game_without_match.id ]
      ActiveRecord::Base.connection.execute(
        "UPDATE games SET competition_id = NULL WHERE id IN (#{ids.join(', ')})"
      )
      AddCompetitionIdToGames.new.backfill_competition_ids
    end

    it "links games to competitions by legacy_season and legacy_series" do
      expect(game_with_match.reload.competition_id).to eq(series_comp.id)
    end

    it "leaves competition_id nil for games with no matching competition" do
      expect(game_without_match.reload.competition_id).to be_nil
    end

    it "does not overwrite an existing competition_id" do
      expect(game_already_linked.reload.competition_id).to eq(other_comp.id)
    end
  end
end
