class MakeGameSlugNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :games, :slug, false
  end
end
