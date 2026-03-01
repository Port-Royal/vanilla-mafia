class PlayersController < ApplicationController
  def show
    result = PlayerProfileService.call(player_id: params[:id])
    @player = result.player
    @pagy, paginated_games = pagy_array(result.games)
    @games_by_season = paginated_games.group_by(&:season)
    @player_awards = result.player_awards
  end
end
