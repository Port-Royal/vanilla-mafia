class AddCompetitionIdToGames < ActiveRecord::Migration[8.1]
  def up
    add_reference :games, :competition, null: true, foreign_key: true

    execute <<~SQL
      UPDATE games
      SET competition_id = (
        SELECT competitions.id
        FROM competitions
        WHERE competitions.legacy_season = games.season
          AND competitions.legacy_series = games.series
      )
    SQL
  end

  def down
    remove_reference :games, :competition, foreign_key: true
  end
end
