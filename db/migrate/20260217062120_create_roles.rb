class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :name, null: false
    end
  end
end
