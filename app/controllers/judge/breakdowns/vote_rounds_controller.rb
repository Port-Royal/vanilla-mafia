class Judge::Breakdowns::VoteRoundsController < Judge::BreakdownBaseController
  before_action :set_breakdown
  before_action :set_round

  def update
    SaveBreakdownVotesService.call(round: @round, ballots: ballots_params)

    respond_with_phase(@round.breakdown_phase)
  end

  def destroy
    phase = @round.breakdown_phase
    @round.destroy!

    respond_with_phase(phase)
  end

  private

  def set_round
    @round = @breakdown.vote_rounds.find(params[:id])
  end

  def ballots_params
    return {} unless params[:votes].is_a?(ActionController::Parameters)

    params[:votes].permit(GameBreakdown::SEAT_NUMBERS.map { |seat| [ seat.to_s, [ :candidate_seat, :for_lift ] ] }.to_h).to_h
  end
end
