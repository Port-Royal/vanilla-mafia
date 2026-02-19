class PlayersController < ApplicationController
  def show
    result = PlayerProfileService.call(player_id: params[:id])
    @player = result.player
    @games_by_season = result.games_by_season
    @player_awards = result.player_awards
  end
end
