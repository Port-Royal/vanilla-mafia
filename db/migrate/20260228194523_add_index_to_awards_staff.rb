class AddIndexToAwardsStaff < ActiveRecord::Migration[8.1]
  def change
    add_index :awards, :staff
  end
end
