class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    add_index :documents, :slug, unique: true
    add_index :documents, [ :published, :position, :id ]
  end
end
