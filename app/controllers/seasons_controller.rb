class SeasonsController < ApplicationController
  def show
    @season = params[:number].to_i
    result = SeasonOverviewService.call(season: @season)
    @games_by_series = result.games_by_series
    @players = result.players
  end
end
