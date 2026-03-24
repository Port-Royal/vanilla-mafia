class CreatePlaybackPositions < ActiveRecord::Migration[8.1]
  def change
    create_table :playback_positions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :episode, null: false, foreign_key: true
      t.integer :position_seconds, null: false, default: 0

      t.timestamps
    end

    add_index :playback_positions, [ :user_id, :episode_id ], unique: true
  end
end
