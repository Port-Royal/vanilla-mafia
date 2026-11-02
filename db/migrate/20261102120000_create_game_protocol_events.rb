class CreateGameProtocolEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :game_protocol_events do |t|
      t.references :game, null: false, foreign_key: true, index: false
      t.string :client_id, null: false
      t.string :action_id, null: false
      t.integer :position, null: false
      t.string :kind, null: false
      t.string :phase, null: false
      t.integer :day_number, null: false
      t.integer :actor_seat
      t.json :target_seats, null: false, default: []
      t.text :text
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :game_protocol_events, [ :game_id, :client_id ], unique: true
    add_index :game_protocol_events, [ :game_id, :position ], unique: true
    add_index :game_protocol_events, [ :game_id, :action_id ]
  end
end
