class CreateNewsPlayerMentions < ActiveRecord::Migration[8.1]
  def change
    create_table :news_player_mentions do |t|
      t.references :news, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true

      t.timestamps
    end

    add_index :news_player_mentions, [ :news_id, :player_id ], unique: true
  end
end
