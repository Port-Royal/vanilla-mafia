class AddSeriesToNews < ActiveRecord::Migration[8.1]
  def change
    add_column :news, :season, :integer
    add_column :news, :series, :integer
    add_index :news, [ :season, :series ]
  end
end
