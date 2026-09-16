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

  # A killed seat only means anything on a kill, so any stale value is dropped with the outcome.
  def phase_params
    permitted = params.require(:breakdown_phase).permit(:night_outcome, :killed_seat)
    outcome = permitted[:night_outcome].presence
    { night_outcome: outcome, killed_seat: outcome == "kill" ? permitted[:killed_seat].presence : nil }
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
