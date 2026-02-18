class SeriesController < ApplicationController
  def show
    @season = params[:season_number].to_i
    @series = params[:number].to_i
    @games = Game.for_season(@season).where(series: @series).ordered
    @ratings_by_player = Rating.where(game: @games).includes(:player).group_by(&:player)
    @players_sorted = @ratings_by_player.keys.sort_by { |p| [ -@ratings_by_player[p].sum(&:total), p.id ] }
  end
end
