class LocalesController < ApplicationController
  def update
    locale = params[:locale]
    return redirect_back(fallback_location: root_path) unless valid_locale?(locale)

    cookies[:locale] = { value: locale, expires: 1.year.from_now }
    current_user.update!(locale: locale) if user_signed_in?

    redirect_back(fallback_location: root_path)
  end

  private

  def valid_locale?(locale)
    locale.present? && I18n.available_locales.map(&:to_s).include?(locale.to_s)
  end
end
