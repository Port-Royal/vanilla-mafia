class AddProtocolFields < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :judge, :string
    add_column :game_participations, :seat, :integer
    add_column :game_participations, :notes, :text
    add_index :game_participations, [ :game_id, :seat ], unique: true
  end
end
