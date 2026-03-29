class Admin::TelegramAuthorsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def create
    @telegram_author = TelegramAuthor.new(telegram_author_params)

    if @telegram_author.save
      ensure_editor_grant(@telegram_author.user) if @telegram_author.user_id
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
    params.require(:telegram_author).permit(:telegram_user_id, :user_id)
  end

  def ensure_editor_grant(user)
    return if user.editor?

    editor_grant = Grant.find_by!(code: "editor")
    user.grants << editor_grant
  end
end
