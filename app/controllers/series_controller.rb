class SeriesController < ApplicationController
  def show
    @season = params[:season_number].to_i
    @series = params[:number].to_i
    result = SeriesAggregationService.call(season: @season, series: @series)
    @games = result.games
    @participations_by_player = result.participations_by_player
    @players_sorted = result.players_sorted
  end
end
