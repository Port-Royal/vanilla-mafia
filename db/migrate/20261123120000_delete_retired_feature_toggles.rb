# The redesigned public site is the only one now, so the toggle that switched it on and the old home page's block
# toggles nothing reads any more are gone from FeatureToggle::KEYS. Their rows would stay in the admin's toggle list
# and fail validation on every save.
class DeleteRetiredFeatureToggles < ActiveRecord::Migration[8.1]
  RETIRED_KEYS = %w[public_redesign home_hero home_hall_of_fame home_stats home_documents home_whats_new].freeze

  def up
    execute(delete_sql)
  end

  # The rows' modes and states are not kept anywhere, and nothing reads the keys any more.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def delete_sql
    "DELETE FROM feature_toggles WHERE key IN (#{RETIRED_KEYS.map { |key| connection.quote(key) }.join(', ')})"
  end
end
