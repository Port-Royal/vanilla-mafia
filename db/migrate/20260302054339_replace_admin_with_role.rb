class ReplaceAdminWithRole < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    add_column :users, :role, :string, null: false, default: "user"
    MigrationUser.where(admin: true).update_all(role: "admin")
    remove_column :users, :admin
  end

  def down
    add_column :users, :admin, :boolean, null: false, default: false
    MigrationUser.where(role: "admin").update_all(admin: true)
    remove_column :users, :role
  end
end
