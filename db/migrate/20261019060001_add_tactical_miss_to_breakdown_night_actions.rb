class AddTacticalMissToBreakdownNightActions < ActiveRecord::Migration[8.1]
  def change
    add_column :breakdown_night_actions, :tactical_miss, :boolean, default: false, null: false
  end
end
