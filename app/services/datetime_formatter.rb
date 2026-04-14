class DatetimeFormatter
  DEFAULT_FORMAT = "european_24h".freeze
  DEFAULT_ZONE = "UTC".freeze

  FORMATS = {
    "european_24h" => {
      date: "%d.%m.%Y",
      datetime: "%d.%m.%Y %H:%M"
    },
    "iso" => {
      date: "%Y-%m-%d",
      datetime: "%Y-%m-%d %H:%M"
    },
    "us_12h" => {
      date: "%m/%d/%Y",
      datetime: "%m/%d/%Y %-l:%M %p"
    }
  }.freeze

  def self.call(value, type:)
    new.call(value, type)
  end

  def call(value, type)
    return "" if value.nil?

    strftime_string = FORMATS.fetch(resolved_format).fetch(type)
    to_zoned(value).strftime(strftime_string)
  end

  private

  def to_zoned(value)
    return value if value.instance_of?(Date)

    value.in_time_zone(resolved_zone)
  end

  def resolved_format
    FORMATS.key?(Current.datetime_format) ? Current.datetime_format : DEFAULT_FORMAT
  end

  def resolved_zone
    zone = Current.time_zone
    return DEFAULT_ZONE if zone.blank?
    return DEFAULT_ZONE if ActiveSupport::TimeZone[zone].nil?

    zone
  end
end
