module DatetimeHelper
  def format_datetime(value)
    DatetimeFormatter.call(value, type: :datetime)
  end

  def format_date(value)
    DatetimeFormatter.call(value, type: :date)
  end
end
