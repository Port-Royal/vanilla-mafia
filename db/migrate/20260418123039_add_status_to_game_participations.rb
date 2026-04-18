class AddStatusToGameParticipations < ActiveRecord::Migration[8.1]
  def change
    add_column :game_participations, :status, :integer, default: 0, null: false
    add_index :game_participations, :status
  end
end
