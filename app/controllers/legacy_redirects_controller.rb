class LegacyRedirectsController < ApplicationController
  def season
    competition = Competition.find_by!(legacy_season: params[:number], legacy_series: nil, kind: :season)
    redirect_to competition_path(slug: competition.slug), status: :moved_permanently
  end

  def series
    competition = Competition.find_by!(legacy_season: params[:season_number], legacy_series: params[:number], kind: :series)
    redirect_to competition_path(slug: competition.slug), status: :moved_permanently
  end
end
