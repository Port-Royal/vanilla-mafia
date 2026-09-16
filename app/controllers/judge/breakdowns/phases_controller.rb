class Judge::Breakdowns::PhasesController < Judge::BreakdownBaseController
  before_action :set_breakdown

  def create
    return render_editor_error(t("game_breakdowns.editor.no_next_phase")) unless AppendBreakdownPhaseService.call(breakdown: @breakdown)

    respond_with_editor
  end

  def destroy
    phase = @breakdown.phases.find(params[:id])
    return render_editor_error(t("game_breakdowns.editor.not_last_phase")) unless deletable?(phase)

    phase.destroy!
    respond_with_editor
  end

  private

  def deletable?(phase)
    @breakdown.phases.count > 1 && @breakdown.phases.maximum(:position) == phase.position
  end
end
