class AddPlaybackSpeedToPlaybackPositions < ActiveRecord::Migration[8.1]
  def change
    add_column :playback_positions, :playback_speed, :float, default: 1.0, null: false
  end
end
