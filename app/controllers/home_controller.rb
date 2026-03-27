class HomeController < ApplicationController
  MINI_STANDINGS_LIMIT = 5
  RECENTLY_FINISHED_LIMIT = 3
  RECENT_GAMES_LIMIT = 5
  LATEST_NEWS_LIMIT = 3
  HALL_OF_FAME_LIMIT = 6

  def index
    @running_competitions = Competition.roots.running.ordered
    @mini_standings = load_mini_standings(@running_competitions)
    @recently_finished = Competition.roots.recently_finished.limit(RECENTLY_FINISHED_LIMIT)
    @winners = load_winners(@recently_finished)
    @recent_games = Game.finished.recent.includes(competition: :parent).limit(RECENT_GAMES_LIMIT)
    @latest_news = News.published.recent.limit(LATEST_NEWS_LIMIT)
    @hall_of_fame_players = load_hall_of_fame_players
  end

  private

  def load_mini_standings(competitions)
    competitions.index_with do |competition|
      Player.with_stats_for_competition(competition).ranked.limit(MINI_STANDINGS_LIMIT)
    end
  end

  def load_winners(competitions)
    competitions.index_with do |competition|
      Player.with_stats_for_competition(competition).ranked.first
    end
  end

  def load_hall_of_fame_players
    Player
      .joins(:player_awards)
      .merge(PlayerAward.joins(:award).where(awards: { staff: false }))
      .distinct
      .includes(photo_attachment: :blob)
      .limit(HALL_OF_FAME_LIMIT)
  end
end
