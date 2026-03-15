class AddCompetitionIdToPlayerAwards < ActiveRecord::Migration[8.1]
  def up
    detect_duplicate_season_competitions
    add_reference :player_awards, :competition, null: true, foreign_key: true
    backfill_competition_ids
  end

  def down
    remove_reference :player_awards, :competition, foreign_key: true
  end

  def backfill_competition_ids
    execute <<~SQL
      UPDATE player_awards
      SET competition_id = c.id
      FROM competitions c
      WHERE c.legacy_season = player_awards.season
        AND c.legacy_series IS NULL
        AND c.kind = 'season'
        AND player_awards.competition_id IS NULL
    SQL
  end

  private

  def detect_duplicate_season_competitions
    duplicates = execute(<<~SQL)
      SELECT legacy_season, COUNT(*) AS cnt
      FROM competitions
      WHERE kind = 'season'
        AND legacy_season IS NOT NULL
        AND legacy_series IS NULL
      GROUP BY legacy_season
      HAVING COUNT(*) > 1
    SQL

    return if duplicates.empty?

    seasons = duplicates.map { |r| r["legacy_season"] }.join(", ")
    raise "Duplicate season competitions found for legacy_season: #{seasons}. Resolve before backfilling."
  end
end
