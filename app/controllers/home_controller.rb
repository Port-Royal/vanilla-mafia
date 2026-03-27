class HomeController < ApplicationController
  MINI_STANDINGS_LIMIT = 5
  RECENTLY_FINISHED_LIMIT = 3
  RECENT_GAMES_LIMIT = 5

  def index
    @running_competitions = Competition.roots.running.ordered
    @mini_standings = load_mini_standings(@running_competitions)
    @recently_finished = Competition.roots.recently_finished.limit(RECENTLY_FINISHED_LIMIT)
    @winners = load_winners(@recently_finished)
    @recent_games = Game.finished.recent.includes(competition: :parent).limit(RECENT_GAMES_LIMIT)
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
end
