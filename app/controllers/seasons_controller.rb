class SeasonsController < ApplicationController
  def show
    @season = params[:number].to_i
    result = SeasonOverviewService.call(season: @season)
    @games_by_series = result.games_by_series
    @pagy, @players = pagy(result.players, limit: 25, count: result.player_count)
  end
end
