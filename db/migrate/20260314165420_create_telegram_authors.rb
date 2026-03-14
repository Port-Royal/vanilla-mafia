class CreateTelegramAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :telegram_authors do |t|
      t.integer :telegram_user_id, null: false
      t.string :telegram_username
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :telegram_authors, :telegram_user_id, unique: true
  end
end
