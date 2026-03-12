class NewsController < ApplicationController
  def index
    scope = News.published.recent.includes(:author, :tags)
    @pagy, @news = pagy(scope)
  end
end
