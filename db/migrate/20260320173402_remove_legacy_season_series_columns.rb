class RemoveLegacySeasonSeriesColumns < ActiveRecord::Migration[8.1]
  def change
    remove_index :games, [ :season, :series ], name: "index_games_on_season_and_series"
    remove_index :games, [ :season ], name: "index_games_on_season"
    remove_column :games, :season, :integer, null: false
    remove_column :games, :series, :integer, null: false

    remove_column :player_awards, :season, :integer

    remove_index :competitions, [ :legacy_season, :legacy_series ], name: "index_competitions_on_legacy_season_and_legacy_series"
    remove_column :competitions, :legacy_season, :integer
    remove_column :competitions, :legacy_series, :integer
  end
end
