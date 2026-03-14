class ChangeGameResultToEnum < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE games SET result = 'peace_victory' WHERE result = 'Победа мирных'"
    execute "UPDATE games SET result = 'mafia_victory' WHERE result = 'Победа мафии'"
    execute "UPDATE games SET result = 'in_progress' WHERE result IS NULL OR result = ''"

    change_column_default :games, :result, "in_progress"
    change_column_null :games, :result, false, "in_progress"
  end

  def down
    change_column_null :games, :result, true
    change_column_default :games, :result, nil

    execute "UPDATE games SET result = 'Победа мирных' WHERE result = 'peace_victory'"
    execute "UPDATE games SET result = 'Победа мафии' WHERE result = 'mafia_victory'"
    execute "UPDATE games SET result = NULL WHERE result = 'in_progress'"
  end
end
