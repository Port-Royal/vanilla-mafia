class CompetitionsController < ApplicationController
  def show
    @competition = Competition.find_by!(slug: params[:slug])
    @result = CompetitionOverviewService.call(competition: @competition)
  end
end
