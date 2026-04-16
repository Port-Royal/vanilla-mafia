module SetPreferences
  extend ActiveSupport::Concern

  DEFAULT_DATETIME_FORMAT = "european_24h".freeze
  DEFAULT_TIME_ZONE = "UTC".freeze

  included do
    before_action :set_preferences
    around_action :use_request_time_zone
  end

  private

  def set_preferences
    I18n.locale = resolve_locale
    Current.datetime_format = resolve_datetime_format
    Current.time_zone = resolve_time_zone
  end

  def use_request_time_zone(&block)
    Time.use_zone(Current.time_zone, &block)
  end

  def resolve_locale
    return current_user.locale.to_sym if user_signed_in?
    return cookies[:locale].to_sym if cookies[:locale].present? && SetPreferences.valid_locale?(cookies[:locale])

    I18n.default_locale
  end

  def resolve_datetime_format
    return current_user.datetime_format if user_signed_in?
    return cookies[:datetime_format] if cookies[:datetime_format].present? && SetPreferences.valid_datetime_format?(cookies[:datetime_format])

    DEFAULT_DATETIME_FORMAT
  end

  def resolve_time_zone
    cookie_tz = cookies[:tz]
    return cookie_tz if cookie_tz.present? && SetPreferences.valid_time_zone?(cookie_tz)

    DEFAULT_TIME_ZONE
  end

  def self.valid_locale?(locale)
    locale_str = locale.to_s
    return false if locale_str.blank?

    I18n.available_locales.map(&:to_s).include?(locale_str)
  end

  def self.valid_datetime_format?(format)
    User.datetime_formats.key?(format.to_s)
  end

  def self.valid_time_zone?(zone)
    zone_str = zone.to_s
    return false if zone_str.blank?

    ActiveSupport::TimeZone[zone_str].present?
  end
end
