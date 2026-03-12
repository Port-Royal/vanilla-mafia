class NewsController < ApplicationController
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: -> { raise ActiveRecord::RecordNotFound }

  def index
    scope = News.published.recent.includes({ author: :player }, :tags, :rich_text_content)
    @pagy, @news = pagy(scope)
  end

  def show
    @article = News.find(params[:id])
    authorize @article
  end
end
