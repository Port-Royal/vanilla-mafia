class CreateAwards < ActiveRecord::Migration[8.1]
  def change
    create_table :awards do |t|
      t.string :title, null: false
      t.integer :position
      t.boolean :staff, default: false
      t.text :description

      t.timestamps
    end
  end
end
