class NewsController < ApplicationController
  ARTICLE_PRELOADS = [ { author: :player }, :tags, :rich_text_content, :competition, { game: :competition },
                       { player_mentions: :player }, { photos_attachments: :blob } ].freeze

  def index
    scope = News.visible.recent.includes({ author: :player }, :tags, :rich_text_content, :competition,
                                          photos_attachments: :blob)

    if classic_pagination?
      @pagy, @news = pagy(scope, limit: news_per_page)
      @pagination_mode = :classic
    elsif infinite_scroll?
      @pagy, @news = pagy(scope, limit: news_per_page)
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

  def show
    @news = News.visible.includes(ARTICLE_PRELOADS).find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def classic_pagination?
    FeatureToggle.enabled?("news_classic_pagination")
  end

  def infinite_scroll?
    FeatureToggle.enabled?("news_infinite_scroll")
  end

  def news_per_page
    FeatureToggle.value_for("news_per_page", default: Pagy::OPTIONS.fetch(:limit, Pagy::DEFAULT[:limit])).to_i
  end
end
