class PlayersController < ApplicationController
  def show
    result = PlayerProfileService.call(player_id: params[:id])
    @player = result.player
    @competitions_with_games = result.competitions_with_games
    @player_awards = result.player_awards
    @news_articles = result.news_articles
    @stats = result.stats
  end
end
