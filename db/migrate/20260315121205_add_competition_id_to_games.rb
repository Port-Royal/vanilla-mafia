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
      SET competition_id = (
        SELECT c.id
        FROM competitions c
        WHERE c.legacy_season = games.season
          AND c.legacy_series = games.series
        ORDER BY c.id
        LIMIT 1
      )
      WHERE games.competition_id IS NULL
        AND EXISTS (
          SELECT 1 FROM competitions c
          WHERE c.legacy_season = games.season
            AND c.legacy_series = games.series
        )
    SQL
  end
end
