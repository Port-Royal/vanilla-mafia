class AddTableNumberToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :table_number, :integer
  end
end
