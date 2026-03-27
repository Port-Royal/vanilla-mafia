class AddIndexOnParentIdAndEndedOnToCompetitions < ActiveRecord::Migration[8.1]
  def change
    add_index :competitions, [ :parent_id, :ended_on ]
  end
end
