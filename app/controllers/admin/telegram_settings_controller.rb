class Admin::TelegramSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def show
    @webhook_info = Telegram::WebhookInfoService.call
    @telegram_authors = TelegramAuthor.includes(:user).order(:telegram_username)
    @telegram_author = TelegramAuthor.new
  end

  private

  def require_admin!
    head :not_found unless current_user.admin?
  end
end
