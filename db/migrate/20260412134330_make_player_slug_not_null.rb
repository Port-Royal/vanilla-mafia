class MakePlayerSlugNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :players, :slug, false
  end
end
