module SetLocale
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private

  def set_locale
    I18n.locale = resolve_locale
  end

  def resolve_locale
    return current_user.locale.to_sym if user_signed_in?
    return cookies[:locale].to_sym if cookies[:locale].present? && valid_locale?(cookies[:locale])

    I18n.default_locale
  end

  def valid_locale?(locale)
    I18n.available_locales.include?(locale.to_sym)
  end
end
