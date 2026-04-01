class Admin::NewsController < ApplicationController
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: -> { head :not_found }

  before_action :authenticate_user!
  before_action :require_news_access!
  before_action :set_news, only: [ :show, :edit, :update, :destroy, :publish, :unpublish ]

  def index
    scope = policy_scope(News).includes({ author: :player }).order(created_at: :asc)
    scope = scope.where(status: params[:status]) if params[:status].present? && News.statuses.key?(params[:status])
    @pagy, @news = pagy(scope)
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
      render :new, status: :unprocessable_content
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
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @news
    @news.destroy!
    redirect_to admin_news_index_path, notice: t("admin_news.destroy.success")
  end

  def publish
    authorize @news, :update?

    unless @news.draft?
      head :unprocessable_content
      return
    end

    @news.publish!
    redirect_to admin_news_path(@news), notice: t("admin_news.publish.success")
  end

  def unpublish
    authorize @news, :update?

    unless @news.published?
      head :unprocessable_content
      return
    end

    @news.unpublish!
    redirect_to admin_news_index_path, notice: t("admin_news.unpublish.success")
  end

  private

  def require_news_access!
    head :not_found unless current_user.can_manage_news?
  end

  def set_news
    @news = News.includes(competition: :parent).find(params[:id])
  end

  def load_form_data
    @seasons = Competition.where(kind: :season).ordered
    @stages_by_season = Competition.where(parent_id: @seasons.select(:id)).ordered.group_by(&:parent_id)
  end

  def news_params
    params.require(:news).permit(:title, :content, :competition_id)
  end
end
