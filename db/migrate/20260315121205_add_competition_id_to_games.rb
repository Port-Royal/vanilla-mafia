class AddCompetitionIdToGames < ActiveRecord::Migration[8.1]
  def up
    add_reference :games, :competition, null: true, foreign_key: true
    backfill_competition_ids
  end

  def down
    remove_reference :games, :competition, foreign_key: true
  end

  def backfill_competition_ids
    detect_duplicate_legacy_mappings

    execute <<~SQL
      UPDATE games
      SET competition_id = (
        SELECT c.id
        FROM competitions c
        WHERE c.legacy_season = games.season
          AND c.legacy_series = games.series
      )
      WHERE games.competition_id IS NULL
    SQL
  end

  private

  def detect_duplicate_legacy_mappings
    duplicates = execute(<<~SQL)
      SELECT legacy_season, legacy_series, COUNT(*) AS cnt
      FROM competitions
      WHERE legacy_season IS NOT NULL AND legacy_series IS NOT NULL
      GROUP BY legacy_season, legacy_series
      HAVING COUNT(*) > 1
    SQL

    return if duplicates.empty?

    pairs = duplicates.map { |r| "(#{r['legacy_season']}, #{r['legacy_series']})" }.join(", ")
    raise "Duplicate (legacy_season, legacy_series) pairs found in competitions: #{pairs}. Resolve before backfilling."
  end
end
