class PopulateCompetitionsFromGames < ActiveRecord::Migration[8.1]
  class MigrationGame < ActiveRecord::Base
    self.table_name = "games"
  end

  class MigrationCompetition < ActiveRecord::Base
    self.table_name = "competitions"
  end

  def up
    season_numbers = MigrationGame.distinct.order(:season).pluck(:season)

    season_numbers.each_with_index do |season_num, idx|
      season = MigrationCompetition.create!(
        kind: "season",
        name: "Сезон #{season_num}",
        slug: "season-#{season_num}",
        position: idx + 1,
        featured: true,
        legacy_season: season_num
      )

      series_numbers = MigrationGame.where(season: season_num).distinct.order(:series).pluck(:series)

      series_numbers.each_with_index do |series_num, s_idx|
        MigrationCompetition.create!(
          kind: "series",
          name: "Серия #{series_num}",
          slug: "season-#{season_num}-series-#{series_num}",
          position: s_idx + 1,
          featured: false,
          parent_id: season.id,
          legacy_season: season_num,
          legacy_series: series_num
        )
      end
    end
  end

  def down
    MigrationCompetition.where.not(legacy_season: nil).delete_all
  end
end
