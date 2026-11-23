class PlayersController < ApplicationController
  def show
    result = PlayerProfileService.call(player_slug: params[:slug])
    @player = result.player
    @player_awards = result.player_awards
    @news_articles = result.news_articles
    @stats = result.stats
    @competition_summaries = result.competition_summaries
    @award_badges = result.award_badges
  end
end
