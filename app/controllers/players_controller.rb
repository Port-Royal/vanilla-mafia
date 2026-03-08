class PlayersController < ApplicationController
  def show
    result = PlayerProfileService.call(player_id: params[:id])
    @player = result.player
    @pagy, games = pagy(result.games)
    @games_by_season = games.group_by(&:season)
    @player_awards = result.player_awards
  end
end
