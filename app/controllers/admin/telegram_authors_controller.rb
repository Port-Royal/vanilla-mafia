class Admin::TelegramAuthorsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def create
    @telegram_author = TelegramAuthor.new(telegram_author_params)

    if @telegram_author.save
      redirect_to admin_telegram_settings_path, notice: t("admin_telegram.authors.create.success")
    else
      redirect_to admin_telegram_settings_path, alert: @telegram_author.errors.full_messages.join(", ")
    end
  end

  def destroy
    @telegram_author = TelegramAuthor.find(params[:id])
    @telegram_author.destroy!
    redirect_to admin_telegram_settings_path, notice: t("admin_telegram.authors.destroy.success")
  end

  private

  def require_admin!
    head :not_found unless current_user.admin?
  end

  def telegram_author_params
    params.require(:telegram_author).permit(:telegram_user_id, :telegram_username, :user_id)
  end
end
