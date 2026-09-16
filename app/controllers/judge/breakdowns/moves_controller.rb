class Judge::Breakdowns::MovesController < Judge::BreakdownBaseController
  before_action :set_breakdown
  before_action :set_move, only: [ :update, :destroy ]

  def create
    move = BreakdownMove.new(move_params)
    assign_context(move)
    move.position = next_move_position(move)
    return render_editor_error(move.errors.full_messages.to_sentence) unless move.save

    respond_with_day(phase_of(move))
  end

  def update
    return render_editor_error(@move.errors.full_messages.to_sentence) unless @move.update(move_params)

    respond_with_day(phase_of(@move))
  end

  def destroy
    phase = phase_of(@move)
    @move.destroy!

    respond_with_day(phase)
  end

  private

  def set_move
    @move = BreakdownMove.where(breakdown_speech_id: @breakdown.speeches.select(:id))
                         .or(BreakdownMove.where(breakdown_vote_round_id: @breakdown.vote_rounds.select(:id)))
                         .find(params[:id])
  end

  def assign_context(move)
    move.breakdown_speech = @breakdown.speeches.find_by(id: params[:speech_id])
    move.breakdown_vote_round = @breakdown.vote_rounds.find_by(id: params[:vote_round_id])
  end

  def phase_of(move)
    return move.breakdown_speech.breakdown_phase if move.breakdown_speech

    move.breakdown_vote_round.breakdown_phase
  end

  def next_move_position(move)
    context = move.breakdown_speech || move.breakdown_vote_round
    return 0 unless context

    next_position(context.moves)
  end

  def move_params
    permitted = params.require(:breakdown_move)
                      .permit(:kind, :actor_seat, :target_seat, :claimed_color, :night_number,
                              :removal_reason, :text, best_move_seats: [])
    permitted.merge(best_move_seats: best_move_seats(permitted))
  end

  def best_move_seats(permitted)
    seats = Array(permitted[:best_move_seats]).compact_blank.map(&:to_i)
    seats.presence
  end
end
