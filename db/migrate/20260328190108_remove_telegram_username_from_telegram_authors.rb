class RemoveTelegramUsernameFromTelegramAuthors < ActiveRecord::Migration[8.1]
  def change
    remove_column :telegram_authors, :telegram_username, :string
  end
end
