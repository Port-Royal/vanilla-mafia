class AddDisputeToPlayerClaims < ActiveRecord::Migration[8.1]
  def change
    add_column :player_claims, :dispute, :boolean, default: false, null: false
    add_column :player_claims, :evidence, :text
  end
end
