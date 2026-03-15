class AddCompetitionIdToGames < ActiveRecord::Migration[8.1]
  def up
    add_reference :games, :competition, null: true, foreign_key: true
    backfill_competition_ids
  end

  def down
    remove_reference :games, :competition, foreign_key: true
  end

  def backfill_competition_ids
    execute <<~SQL
      UPDATE games
      SET competition_id = competitions.id
      FROM competitions
      WHERE competitions.legacy_season = games.season
        AND competitions.legacy_series = games.series
        AND games.competition_id IS NULL
    SQL
  end
end
