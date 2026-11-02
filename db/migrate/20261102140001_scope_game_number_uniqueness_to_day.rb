class ScopeGameNumberUniquenessToDay < ActiveRecord::Migration[8.1]
  def change
    remove_index :games, [ :competition_id, :game_number ], unique: true, name: "index_games_on_competition_id_and_game_number"
    add_index :games, [ :competition_id, :played_on, :table_number, :game_number ], unique: true, name: "index_games_on_competition_day_table_and_number"
  end
end
