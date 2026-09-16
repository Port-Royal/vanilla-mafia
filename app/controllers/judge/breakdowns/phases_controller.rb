class Judge::Breakdowns::PhasesController < Judge::BreakdownBaseController
  before_action :set_breakdown

  def create
    return render_editor_error(t("game_breakdowns.editor.no_next_phase")) unless AppendBreakdownPhaseService.call(breakdown: @breakdown)

    respond_with_editor
  end

  def update
    phase = @breakdown.phases.find(params[:id])
    return render_editor_error(phase.errors.full_messages.to_sentence) unless phase.update(phase_params)

    SaveBreakdownNightService.call(phase: phase, shots: shots_params, checks: checks_params)
    respond_with_phase(phase)
  end

  def destroy
    phase = @breakdown.phases.find(params[:id])
    return render_editor_error(t("game_breakdowns.editor.not_last_phase")) unless deletable?(phase)

    phase.destroy!
    respond_with_editor
  end

  private

  # The night outcome arrives as one value — "", "miss" or "kill:<seat>" — so a kill always carries its seat
  # and any other outcome drops a stale one.
  def phase_params
    outcome, seat = params.require(:breakdown_phase).permit(:outcome)[:outcome].to_s.split(":")
    { night_outcome: outcome.presence, killed_seat: seat }
  end

  def shots_params
    nested_params(:shots, GameBreakdown::SEAT_NUMBERS.map(&:to_s))
  end

  def checks_params
    nested_params(:checks, SaveBreakdownNightService::CHECK_KINDS)
  end

  def nested_params(key, permitted_keys)
    return {} unless params[key].is_a?(ActionController::Parameters)

    params[key].permit(*permitted_keys).to_h
  end

  def deletable?(phase)
    @breakdown.phases.count > 1 && @breakdown.phases.maximum(:position) == phase.position
  end
end
