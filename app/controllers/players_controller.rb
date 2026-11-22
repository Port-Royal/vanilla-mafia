class PlayersController < ApplicationController
  def show
    result = PlayerProfileService.call(player_slug: params[:slug])
    @player = result.player
    @competitions_with_games = result.competitions_with_games
    @player_awards = result.player_awards
    @news_articles = result.news_articles
    @stats = result.stats
    @competition_summaries = result.competition_summaries
    @award_badges = result.award_badges
    render "players/redesign/show" if helpers.new_design?
  end
end
