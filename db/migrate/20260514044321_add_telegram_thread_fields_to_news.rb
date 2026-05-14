class AddTelegramThreadFieldsToNews < ActiveRecord::Migration[8.1]
  def change
    change_table :news, bulk: true do |t|
      t.datetime :telegram_thread_started_at
      t.datetime :telegram_thread_last_message_at
    end

    add_index :news, [ :author_id, :status, :telegram_thread_last_message_at ], name: "index_news_on_author_status_thread"
  end
end
