class CreateNews < ActiveRecord::Migration[8.1]
  def change
    create_table :news do |t|
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :game, foreign_key: true

      t.timestamps
    end

    add_index :news, :published_at
  end
end
