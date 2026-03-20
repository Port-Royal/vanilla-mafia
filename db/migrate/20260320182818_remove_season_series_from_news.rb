class RemoveSeasonSeriesFromNews < ActiveRecord::Migration[8.1]
  def change
    remove_index :news, [ :season, :series ], name: "index_news_on_season_and_series"
    remove_column :news, :season, :integer
    remove_column :news, :series, :integer
  end
end
