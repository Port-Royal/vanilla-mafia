class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.string :version, null: false
      t.string :grant_code
      t.text :message, null: false

      t.timestamps
    end

    add_index :announcements, :grant_code
  end
end
