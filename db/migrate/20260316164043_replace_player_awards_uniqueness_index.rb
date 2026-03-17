class ReplacePlayerAwardsUniquenessIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :player_awards, [ :player_id, :award_id, :season ], unique: true
    add_index :player_awards, [ :player_id, :award_id, :competition_id ], unique: true
  end
end
