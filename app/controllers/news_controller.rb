class NewsController < ApplicationController
  def index
    scope = News.visible.recent.includes({ author: :player }, :tags, :rich_text_content, photos_attachments: :blob)
    @pagy, @news = pagy(scope)
  end
end
