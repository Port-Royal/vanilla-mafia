class RemoveLegacyUniqueIndexFromGames < ActiveRecord::Migration[8.1]
  def change
    remove_index :games, [ :season, :series, :game_number ],
                 name: "index_games_on_season_and_series_and_game_number",
                 unique: true
  end
end
