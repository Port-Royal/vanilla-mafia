class AddValueToFeatureToggles < ActiveRecord::Migration[8.1]
  def change
    add_column :feature_toggles, :value, :string
  end
end
