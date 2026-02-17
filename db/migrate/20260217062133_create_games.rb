class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.date :played_on
      t.integer :season, null: false
      t.integer :series, null: false
      t.integer :game_number, null: false
      t.string :name
      t.string :result

      t.timestamps
    end

    add_index :games, [ :season, :series, :game_number ], unique: true
    add_index :games, :season
    add_index :games, [ :season, :series ]
  end
end
