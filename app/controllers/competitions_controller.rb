class CompetitionsController < ApplicationController
  def show
    @competition = Competition.find_by!(slug: params[:slug])
    result = CompetitionOverviewService.call(competition: @competition)
    @parent_view = result.parent_view
    @games_by_child = result.games_by_child
  end
end
