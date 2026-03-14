class ChangeGameResultToEnum < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE games SET result = 'peace_victory' WHERE result = 'Победа мирных';
      UPDATE games SET result = 'mafia_victory' WHERE result = 'Победа мафии';
      UPDATE games SET result = 'in_progress' WHERE result IS NULL OR result = '';
    SQL

    change_column_default :games, :result, "in_progress"
    change_column_null :games, :result, false, "in_progress"
  end

  def down
    change_column_null :games, :result, true
    change_column_default :games, :result, nil

    execute <<~SQL
      UPDATE games SET result = 'Победа мирных' WHERE result = 'peace_victory';
      UPDATE games SET result = 'Победа мафии' WHERE result = 'mafia_victory';
      UPDATE games SET result = NULL WHERE result = 'in_progress';
    SQL
  end
end
