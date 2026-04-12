class MakeNewsSlugNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :news, :slug, false
  end
end
