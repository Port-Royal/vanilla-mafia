class FeatureToggle < ApplicationRecord
  KEYS = %w[require_approval].freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }
  validates :enabled, inclusion: { in: [ true, false ] }

  def self.enabled?(key)
    toggle = find_by(key: key)
    return false if toggle.nil?

    toggle.enabled
  end
end
