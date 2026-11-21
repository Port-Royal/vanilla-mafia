class CompetitionsController < ApplicationController
  def show
    @competition = Competition.find_by!(slug: params[:slug])
    overview = CompetitionOverviewService.new(@competition)
    result = overview.call
    @parent_view = result.parent_view
    @news = result.news

    if @parent_view
      @games_by_child = result.games_by_child
      @players = result.players
    else
      @games = result.games
      @participations_by_player = result.participations_by_player
      @players_sorted = result.players_sorted
    end

    render_new_design(overview) if helpers.new_design?
  end

  private

  # The header counts every game in the subtree, as the standings do; a child's row lists only its direct games.
  def render_new_design(overview)
    @child_winners = overview.child_winners
    @games_count = Game.where(competition_id: @competition.subtree_ids).count
    render "competitions/redesign/show"
  end
end
