class AddDatetimeFormatToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :datetime_format, :string, default: "european_24h", null: false
  end
end
