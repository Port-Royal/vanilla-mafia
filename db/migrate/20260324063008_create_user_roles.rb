class CreateUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end

    add_index :user_roles, [ :user_id, :role ], unique: true
  end
end
