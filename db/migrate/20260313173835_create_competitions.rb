class CreateCompetitions < ActiveRecord::Migration[8.1]
  def change
    create_table :competitions do |t|
      t.references :parent, null: true, foreign_key: { to_table: :competitions }
      t.string :kind, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position
      t.date :started_on
      t.date :ended_on
      t.boolean :featured, default: false, null: false
      t.integer :legacy_season
      t.integer :legacy_series
      t.timestamps
    end

    add_index :competitions, :slug, unique: true
    add_index :competitions, :kind
    add_index :competitions, :featured
    add_index :competitions, [ :legacy_season, :legacy_series ]
  end
end
