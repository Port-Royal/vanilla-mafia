# The redesigned public site is the only one now, so the toggle that switched it on is gone from FeatureToggle::KEYS.
# Its row would stay in the admin's toggle list and fail validation on every save.
class DeletePublicRedesignToggle < ActiveRecord::Migration[8.1]
  def up
    execute(delete_sql)
  end

  # The row's mode and state are not kept anywhere, and nothing reads the key any more.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def delete_sql
    "DELETE FROM feature_toggles WHERE key = 'public_redesign'"
  end
end
