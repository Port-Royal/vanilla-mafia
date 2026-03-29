class CreatePodcastFeedTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :podcast_feed_tokens do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :token, null: false
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :podcast_feed_tokens, :token, unique: true
  end
end
