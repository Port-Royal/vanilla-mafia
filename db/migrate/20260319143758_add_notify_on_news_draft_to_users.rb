class AddNotifyOnNewsDraftToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notify_on_news_draft, :boolean, default: true, null: false
  end
end
