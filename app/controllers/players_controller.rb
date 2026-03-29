class PlayersController < ApplicationController
  def show
    result = PlayerProfileService.call(player_id: params[:id])
    @player = result.player
    @pagy, games = pagy(result.games)
    @games_by_competition = games.group_by { |g| g.competition.root }
    @player_awards = result.player_awards
    @news_articles = result.news_articles
    @stats = result.stats
  end
end
