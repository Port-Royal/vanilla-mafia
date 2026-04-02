class FeatureToggle < ApplicationRecord
  KEYS = %w[
    require_approval
    home_hero
    home_running_tournaments
    home_recently_finished
    home_recent_games
    home_latest_news
    home_hall_of_fame
    home_stats
    home_documents
    home_whats_new
    toast_whats_new
    news_classic_pagination
    news_infinite_scroll
  ].freeze
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

  def self.disabled?(key)
    Rails.cache.fetch(cache_key_for("#{key}_disabled"), expires_in: CACHE_TTL) do
      toggle = find_by(key: key)
      toggle.present? && !toggle.enabled
    end
  end

  def self.cache_key_for(key)
    "feature_toggle/#{key}"
  end

  private

  def clear_cache
    if respond_to?(:saved_change_to_key?) && saved_change_to_key?
      old_key, new_key = saved_change_to_key
      clear_cache_for(old_key)
      clear_cache_for(new_key)
    else
      clear_cache_for(key)
    end
  end

  def clear_cache_for(toggle_key)
    return if toggle_key.blank?

    self.class.cache_key_for(toggle_key).then { |k| Rails.cache.delete(k) }
    self.class.cache_key_for("#{toggle_key}_disabled").then { |k| Rails.cache.delete(k) }
  end
end
