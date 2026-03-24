class CreateGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :grants do |t|
      t.string :code, null: false

      t.timestamps
    end

    add_index :grants, :code, unique: true
  end
end
