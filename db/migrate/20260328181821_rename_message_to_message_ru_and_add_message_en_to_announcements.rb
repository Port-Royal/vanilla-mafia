class RenameMessageToMessageRuAndAddMessageEnToAnnouncements < ActiveRecord::Migration[8.1]
  def change
    rename_column :announcements, :message, :message_ru
    add_column :announcements, :message_en, :string, null: false, default: ""
    change_column_default :announcements, :message_en, from: "", to: nil
  end
end
