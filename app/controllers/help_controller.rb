class HelpController < ApplicationController
  PAGES = %w[obs-overlay podcast-feed game-breakdown].freeze

  # A page documenting a feature that is switched off would describe something the reader cannot reach,
  # so it is hidden with the feature, exactly like the menu entry.
  TOGGLED_PAGES = { "game-breakdown" => "game_breakdown" }.freeze

  def index
    @pages = PAGES.select { |slug| available?(slug) }
  end

  # The whitelist check stands alone: show.html.erb renders the partial by slug, and Brakeman only
  # recognises the render path as safe while a bare PAGES.include? guards it.
  def show
    @slug = params[:slug]
    raise ActiveRecord::RecordNotFound unless PAGES.include?(@slug)
    raise ActiveRecord::RecordNotFound unless available?(@slug)
  end

  private

  def available?(slug)
    toggle_key = TOGGLED_PAGES[slug]
    toggle_key.nil? || FeatureToggle.enabled?(toggle_key)
  end
end
