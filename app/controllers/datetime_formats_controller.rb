class DatetimeFormatsController < ApplicationController
  def update
    format = params[:datetime_format]
    return redirect_back(fallback_location: root_path) unless valid_format?(format)

    cookies[:datetime_format] = { value: format, expires: 1.year.from_now }
    current_user.update!(datetime_format: format) if user_signed_in?

    redirect_back(fallback_location: root_path)
  end

  private

  def valid_format?(format)
    User.datetime_formats.key?(format.to_s)
  end
end
