class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :game, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.string :role_code
      t.boolean :first_shoot, default: false
      t.boolean :win, default: false
      t.decimal :plus, precision: 5, scale: 2, default: 0
      t.decimal :minus, precision: 5, scale: 2, default: 0
      t.decimal :best_move, precision: 5, scale: 2

      t.timestamps
    end

    add_index :ratings, [ :game_id, :player_id ], unique: true
    add_foreign_key :ratings, :roles, column: :role_code, primary_key: :code
  end
end
