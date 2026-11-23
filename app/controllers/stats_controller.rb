# The club's numbers.
class StatsController < ApplicationController
  def show
    @stats = ClubStatsService.call
  end
end
