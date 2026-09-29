class AddBestMoveSeatsToGameParticipations < ActiveRecord::Migration[8.1]
  def change
    add_column :game_participations, :best_move_seats, :json
  end
end
