class RenameRatingsToGameParticipations < ActiveRecord::Migration[8.1]
  def change
    rename_table :ratings, :game_participations
  end
end
