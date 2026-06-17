class AddTelegramMessageIdsToNews < ActiveRecord::Migration[8.1]
  def change
    add_column :news, :telegram_message_ids, :json, null: false, default: []
  end
end
