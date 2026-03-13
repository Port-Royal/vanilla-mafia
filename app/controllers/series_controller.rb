class SeriesController < ApplicationController
  def show
    @season = params[:season_number].to_i
    @series = params[:number].to_i
    result = SeriesAggregationService.call(season: @season, series: @series)
    @games = result.games
    @participations_by_player = result.participations_by_player
    @players_sorted = result.players_sorted
    @news = News.published.for_series(@season, @series).recent.includes({ author: :player }, :tags, :rich_text_content).limit(5).load
  end
end
