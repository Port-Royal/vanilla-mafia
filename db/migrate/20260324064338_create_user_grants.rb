class CreateUserGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :user_grants do |t|
      t.references :user, null: false, foreign_key: true
      t.references :grant, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_grants, [ :user_id, :grant_id ], unique: true
  end
end
