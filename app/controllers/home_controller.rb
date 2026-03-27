class HomeController < ApplicationController
  MINI_STANDINGS_LIMIT = 5

  def index
    @running_competitions = Competition.roots.running.ordered
    @mini_standings = load_mini_standings(@running_competitions)
  end

  private

  def load_mini_standings(competitions)
    competitions.index_with do |competition|
      Player.with_stats_for_competition(competition).ranked.limit(MINI_STANDINGS_LIMIT)
    end
  end
end
