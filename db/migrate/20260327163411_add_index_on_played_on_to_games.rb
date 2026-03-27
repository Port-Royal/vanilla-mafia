class AddIndexOnPlayedOnToGames < ActiveRecord::Migration[8.1]
  def change
    add_index :games, [ :played_on, :game_number ]
  end
end
