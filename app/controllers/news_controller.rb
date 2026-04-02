class NewsController < ApplicationController
  def index
    scope = News.visible.recent.includes({ author: :player }, :tags, :rich_text_content, photos_attachments: :blob)

    if classic_pagination?
      @pagy, @news = pagy(scope)
      @pagination_mode = :classic
    elsif infinite_scroll?
      @pagy, @news = pagy(scope)
      @pagination_mode = :infinite
    else
      @news = scope.to_a
      @pagination_mode = :none
    end

    respond_to do |format|
      format.html
      format.turbo_stream if @pagination_mode == :infinite
    end
  end

  private

  def classic_pagination?
    FeatureToggle.enabled?("news_classic_pagination")
  end

  def infinite_scroll?
    FeatureToggle.enabled?("news_infinite_scroll")
  end
end
