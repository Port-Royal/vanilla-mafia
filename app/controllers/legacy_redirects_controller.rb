class LegacyRedirectsController < ApplicationController
  def season
    competition = Competition.find_by!(slug: "season-#{params[:number]}", kind: :season)
    redirect_to competition_path(slug: competition.slug), status: :moved_permanently
  end

  def series
    competition = Competition.find_by!(slug: "season-#{params[:season_number]}-series-#{params[:number]}", kind: :series)
    redirect_to competition_path(slug: competition.slug), status: :moved_permanently
  end
end
