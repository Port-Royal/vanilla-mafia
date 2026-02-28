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

  def self.valid_locale?(locale)
    locale_str = locale.to_s
    return false if locale_str.blank?

    I18n.available_locales.map(&:to_s).include?(locale_str)
  end

  def valid_locale?(locale)
    SetLocale.valid_locale?(locale)
  end
end
