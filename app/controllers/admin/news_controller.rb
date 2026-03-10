class Admin::NewsController < ApplicationController
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: -> { head :not_found }

  before_action :authenticate_user!
  before_action :require_news_access!
  before_action :set_news, only: [ :show, :edit, :update, :destroy, :publish ]

  def index
    @news = policy_scope(News).includes(:author).recent
  end

  def show
    authorize @news
  end

  def new
    @news = News.new
    authorize @news
    load_form_data
  end

  def create
    @news = News.new(news_params)
    @news.author = current_user
    authorize @news

    if @news.save
      redirect_to admin_news_index_path, notice: t("admin_news.create.success")
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @news
    load_form_data
  end

  def update
    authorize @news

    if @news.update(news_params)
      redirect_to admin_news_path(@news), notice: t("admin_news.update.success")
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @news
    @news.destroy!
    redirect_to admin_news_index_path, notice: t("admin_news.destroy.success")
  end

  def publish
    authorize @news, :update?
    head :unprocessable_entity and return unless @news.draft?

    @news.publish!
    redirect_to admin_news_path(@news), notice: t("admin_news.publish.success")
  end

  private

  def require_news_access!
    head :not_found unless current_user.can_manage_news?
  end

  def set_news
    @news = News.find(params[:id])
  end

  def load_form_data
    @games = Game.order(played_on: :desc)
  end

  def news_params
    params.require(:news).permit(:title, :content, :game_id)
  end
end
