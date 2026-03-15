require "rails_helper"
require_relative "../../db/migrate/20260315121205_add_competition_id_to_games"

RSpec.describe "AddCompetitionIdToGames migration" do
  describe "schema" do
    it "adds competition_id column to games" do
      column = Game.column_for_attribute(:competition_id)
      expect(column.type).to eq(:integer)
      expect(column.null).to be false
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

  # Backfill tests removed: competition_id is now NOT NULL, so the backfill
  # scenario (setting NULL then re-running) can no longer be simulated.
  # The backfill was verified when the migration was originally applied.
end
