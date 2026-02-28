class AddUniqueIndexToPlayersName < ActiveRecord::Migration[8.1]
  def change
    add_index :players, :name, unique: true
  end
end
