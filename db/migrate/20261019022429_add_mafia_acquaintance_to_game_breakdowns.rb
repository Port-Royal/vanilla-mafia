class AddMafiaAcquaintanceToGameBreakdowns < ActiveRecord::Migration[8.1]
  def change
    add_column :game_breakdowns, :mafia_acquaintance, :text
  end
end
