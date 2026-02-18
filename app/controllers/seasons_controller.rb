class SeasonsController < ApplicationController
  def show
    @season = params[:number].to_i
    @games_by_series = Game.for_season(@season).ordered.group_by(&:series)
    @players = Player.with_stats_for_season(@season).ranked
  end
end
