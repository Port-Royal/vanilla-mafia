class AddTelegramMessageKeysToNews < ActiveRecord::Migration[8.1]
  def change
    add_column :news, :telegram_message_keys, :json, null: false, default: []
  end
end
