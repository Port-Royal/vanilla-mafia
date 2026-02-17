class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :name, null: false
      t.text :comment
      t.integer :position

      t.timestamps
    end
  end
end
