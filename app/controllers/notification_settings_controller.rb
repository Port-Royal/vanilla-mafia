class NotificationSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_news_manager

  def edit
  end

  def update
    current_user.update!(user_params)
    redirect_to edit_notification_settings_path, notice: t(".success")
  end

  private

  def ensure_news_manager
    return if current_user.can_manage_news?

    redirect_to root_path, alert: t("notification_settings.errors.unauthorized")
  end

  def user_params
    params.expect(user: [ :notify_on_news_draft ])
  end
end
