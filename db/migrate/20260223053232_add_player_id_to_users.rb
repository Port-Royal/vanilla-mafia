class AddPlayerIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :player, null: true, foreign_key: true, index: { unique: true }
  end
end
