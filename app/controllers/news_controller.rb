class NewsController < ApplicationController
  def index
    scope = News.published.recent.includes(:author, :tags, :rich_text_content)
    @pagy, @news = pagy(scope)
  end
end
