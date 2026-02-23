class CreatePlayerClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :player_claims do |t|
      t.references :user, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.text :rejection_reason
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :player_claims, [ :user_id, :player_id ], unique: true
    add_index :player_claims, :status
  end
end
