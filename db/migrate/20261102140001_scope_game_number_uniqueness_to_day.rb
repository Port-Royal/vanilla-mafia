class ScopeGameNumberUniquenessToDay < ActiveRecord::Migration[8.1]
  # A unique index treats NULLs as distinct, so a blank date or table is folded into a constant;
  # otherwise two undated or tableless games could share a number.
  UNIQUE_EXPRESSION = "competition_id, COALESCE(played_on, ''), COALESCE(table_number, 0), game_number".freeze

  def change
    remove_index :games, [ :competition_id, :game_number ], unique: true, name: "index_games_on_competition_id_and_game_number"
    add_index :games, UNIQUE_EXPRESSION, unique: true, name: "index_games_on_competition_day_table_and_number"
  end
end
