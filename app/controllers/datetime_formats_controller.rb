class DatetimeFormatsController < ApplicationController
  def update
    fmt = params[:datetime_format]
    return redirect_back(fallback_location: root_path) unless valid_format?(fmt)

    cookies[:datetime_format] = { value: fmt, expires: 1.year.from_now }
    current_user.update!(datetime_format: fmt) if user_signed_in?

    redirect_back(fallback_location: root_path)
  end

  private

  def valid_format?(fmt)
    User.datetime_formats.key?(fmt.to_s)
  end
end
