class PlayersController < ApplicationController
  def show
    @player = Player.find(params[:id])
    @games_by_season = @player.games.ordered.group_by(&:season)
    @player_awards = @player.player_awards.ordered.includes(:award).load
  end
end
