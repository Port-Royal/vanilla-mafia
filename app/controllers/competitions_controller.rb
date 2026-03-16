class CompetitionsController < ApplicationController
  def show
    @competition = Competition.find_by!(slug: params[:slug])
    result = CompetitionOverviewService.call(competition: @competition)
    @parent_view = result.parent_view

    if @parent_view
      @games_by_child = result.games_by_child
      @pagy, @players = pagy(result.players, limit: 25, count: result.player_count)
    else
      @games = result.games
      @participations_by_player = result.participations_by_player
      @players_sorted = result.players_sorted
    end
  end
end
