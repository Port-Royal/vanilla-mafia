class SeasonsController < ApplicationController
  def show
    @season = params[:number].to_i
    result = SeasonOverviewService.call(season: @season)
    @games_by_series = result.games_by_series
    @pagy, @players = pagy_array(result.players.to_a)
  end
end
