class MakeCompetitionIdNotNullOnGames < ActiveRecord::Migration[8.1]
  def change
    change_column_null :games, :competition_id, false
  end
end
