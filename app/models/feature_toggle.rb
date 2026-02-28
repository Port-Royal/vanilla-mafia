class FeatureToggle < ApplicationRecord
  KEYS = %w[require_approval].freeze
  CACHE_TTL = 5.minutes

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }
  validates :enabled, inclusion: { in: [ true, false ] }

  after_commit :clear_cache

  def self.enabled?(key)
    Rails.cache.fetch(cache_key_for(key), expires_in: CACHE_TTL) do
      toggle = find_by(key: key)
      toggle.nil? ? false : toggle.enabled
    end
  end

  def self.cache_key_for(key)
    "feature_toggle/#{key}"
  end

  private

  def clear_cache
    Rails.cache.delete(self.class.cache_key_for(key))
  end
end
