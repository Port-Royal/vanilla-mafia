class ReplaceAdminWithRole < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :string, null: false, default: "user"
    User.where(admin: true).update_all(role: "admin")
    remove_column :users, :admin
  end

  def down
    add_column :users, :admin, :boolean, null: false, default: false
    User.where(role: "admin").update_all(admin: true)
    remove_column :users, :role
  end
end
