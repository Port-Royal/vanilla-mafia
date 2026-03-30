class HelpController < ApplicationController
  PAGES = %w[obs-overlay podcast-feed].freeze

  def index
    @pages = PAGES
  end

  def show
    @slug = params[:slug]
    raise ActiveRecord::RecordNotFound unless PAGES.include?(@slug)
  end
end
