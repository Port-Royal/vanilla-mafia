class DesignPreferencesController < ApplicationController
  def update
    design = params[:design]
    return back_to_site unless DesignPreference::CHOICES.include?(design)

    cookies[DesignPreference::COOKIE] = { value: design, expires: 1.year.from_now }

    back_to_site
  end

  private

  def back_to_site
    redirect_back(fallback_location: root_path, allow_other_host: false)
  end
end
