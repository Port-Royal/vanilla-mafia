class CreatePlayerAwards < ActiveRecord::Migration[8.1]
  def change
    create_table :player_awards do |t|
      t.references :player, null: false, foreign_key: true
      t.references :award, null: false, foreign_key: true
      t.integer :season
      t.integer :position

      t.timestamps
    end

    add_index :player_awards, [:player_id, :award_id, :season], unique: true
  end
end
