class BackfillGameParticipationSeats < ActiveRecord::Migration[8.1]
  def up
    execute(backfill_sql)
  end

  def down
    # Irreversible: we cannot distinguish originally-nil seats from backfilled ones
  end

  def backfill_sql
    <<~SQL
      UPDATE game_participations
      SET seat = numbered.row_num
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY game_id ORDER BY id) AS row_num
        FROM game_participations
        WHERE seat IS NULL
      ) AS numbered
      WHERE game_participations.id = numbered.id
    SQL
  end
end
