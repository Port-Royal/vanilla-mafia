class HelpController < ApplicationController
  PAGES = %w[obs-overlay].freeze

  def index
    @pages = PAGES
  end

  def show
    slug = params[:slug]
    head :not_found unless PAGES.include?(slug)

    @slug = slug
  end
end
