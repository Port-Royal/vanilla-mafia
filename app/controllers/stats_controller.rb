# The club's numbers. The page exists only in the redesigned site; the old design keeps them on its home page.
class StatsController < ApplicationController
  before_action :require_new_design

  def show
    @stats = ClubStatsService.call
    render "stats/redesign/show"
  end

  private

  # Removed with the public_redesign toggle (vm-bpk.10).
  def require_new_design
    raise ActionController::RoutingError, "Not Found" unless helpers.new_design?
  end
end
