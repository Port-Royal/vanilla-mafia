class HelpController < ApplicationController
  PAGES = %w[obs-overlay podcast-feed game-breakdown].freeze

  # A page documenting a feature that is switched off would describe something the reader cannot reach,
  # so it is hidden with the feature, exactly like the menu entry.
  TOGGLED_PAGES = { "game-breakdown" => "game_breakdown" }.freeze

  def index
    @pages = PAGES.select { |slug| available?(slug) }
  end

  def show
    @slug = params[:slug]
    raise ActiveRecord::RecordNotFound unless PAGES.include?(@slug) && available?(@slug)
  end

  private

  def available?(slug)
    toggle_key = TOGGLED_PAGES[slug]
    toggle_key.nil? || FeatureToggle.enabled?(toggle_key)
  end
end
