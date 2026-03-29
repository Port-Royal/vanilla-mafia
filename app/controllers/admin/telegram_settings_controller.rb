class Admin::TelegramSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def show
    @webhook_info = Telegram::WebhookInfoService.call
    @telegram_authors = TelegramAuthor.includes(user: :player).order(:telegram_user_id)
    @telegram_author = TelegramAuthor.new
    @users = User.joins(:player).includes(:player).order("players.name")
  end

  private

  def require_admin!
    head :not_found unless current_user.admin?
  end
end
