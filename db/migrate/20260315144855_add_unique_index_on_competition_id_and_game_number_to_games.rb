class AddUniqueIndexOnCompetitionIdAndGameNumberToGames < ActiveRecord::Migration[8.1]
  def change
    add_index :games, [ :competition_id, :game_number ], unique: true
  end
end
