class AddSlugToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :slug, :string
    add_index :players, :slug, unique: true
  end
end
