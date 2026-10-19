class RemoveSourceFromGameBreakdowns < ActiveRecord::Migration[8.1]
  def change
    remove_column :game_breakdowns, :source, :string
  end
end
