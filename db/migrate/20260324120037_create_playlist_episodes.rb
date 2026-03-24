class CreatePlaylistEpisodes < ActiveRecord::Migration[8.1]
  def change
    create_table :playlist_episodes do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :episode, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps

      t.index [ :playlist_id, :episode_id ], unique: true
      t.index [ :playlist_id, :position ], unique: true
    end
  end
end
