class CreateAnnouncementDismissals < ActiveRecord::Migration[8.1]
  def change
    create_table :announcement_dismissals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :announcement, null: false, foreign_key: true

      t.timestamps
    end

    add_index :announcement_dismissals, [ :user_id, :announcement_id ], unique: true
  end
end
