class AddBioToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :bio, :text
  end
end
