class AddPlayerToTelegramAuthors < ActiveRecord::Migration[8.1]
  def change
    add_reference :telegram_authors, :player, null: true, foreign_key: true
  end
end
