class AddOverlayDisplaySettingsToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :hide_roles, :boolean, default: false, null: false
    add_column :games, :hide_game_info, :boolean, default: false, null: false
    add_column :games, :hide_table_info, :boolean, default: false, null: false
  end
end
