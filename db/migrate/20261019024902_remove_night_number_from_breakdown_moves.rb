class RemoveNightNumberFromBreakdownMoves < ActiveRecord::Migration[8.1]
  def change
    remove_column :breakdown_moves, :night_number, :integer
  end
end
