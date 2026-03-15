require "rails_helper"
require_relative "../../db/migrate/20260315142549_add_competition_id_to_player_awards"

RSpec.describe "AddCompetitionIdToPlayerAwards migration" do
  describe "schema" do
    it "adds competition_id column to player_awards" do
      column = PlayerAward.column_for_attribute(:competition_id)
      expect(column.type).to eq(:integer)
      expect(column.null).to be true
    end

    it "has an index on competition_id" do
      expect(ActiveRecord::Base.connection.index_exists?(:player_awards, :competition_id)).to be true
    end

    it "has a foreign key to competitions" do
      foreign_keys = ActiveRecord::Base.connection.foreign_keys(:player_awards)
      fk = foreign_keys.find { |fk| fk.column == "competition_id" }
      expect(fk).to be_present
      expect(fk.to_table).to eq("competitions")
    end
  end

  describe "backfill" do
    let_it_be(:season_comp) { create(:competition, :season, legacy_season: 3, legacy_series: nil) }
    let_it_be(:other_season_comp) { create(:competition, :season, legacy_season: 7, legacy_series: nil) }
    let_it_be(:award_with_match) { create(:player_award, season: 3) }
    let_it_be(:award_without_match) { create(:player_award, season: 99) }
    let_it_be(:award_already_linked) { create(:player_award, season: 7) }

    before_all do
      ActiveRecord::Base.connection.execute(
        "UPDATE player_awards SET competition_id = #{other_season_comp.id} WHERE id = #{award_already_linked.id}"
      )
      ids = [ award_with_match.id, award_without_match.id ]
      ActiveRecord::Base.connection.execute(
        "UPDATE player_awards SET competition_id = NULL WHERE id IN (#{ids.join(', ')})"
      )
      AddCompetitionIdToPlayerAwards.new.backfill_competition_ids
    end

    it "links player_awards to season competitions by season" do
      expect(award_with_match.reload.competition_id).to eq(season_comp.id)
    end

    it "leaves competition_id nil for awards with no matching competition" do
      expect(award_without_match.reload.competition_id).to be_nil
    end

    it "does not overwrite an existing competition_id" do
      expect(award_already_linked.reload.competition_id).to eq(other_season_comp.id)
    end
  end
end
