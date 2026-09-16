class Judge::Breakdowns::SpeechesController < Judge::BreakdownBaseController
  MANUAL_KINDS = %w[regular farewell].freeze

  before_action :set_breakdown

  def create
    phase = @breakdown.phases.find(params[:breakdown_phase_id])
    speech = phase.speeches.new(speech_params)
    speech.position = next_position(phase.speeches)
    return render_editor_error(speech.errors.full_messages.to_sentence) unless speech.save

    respond_with_day(phase)
  end

  def destroy
    speech = @breakdown.speeches.find(params[:id])
    phase = speech.breakdown_phase
    speech.destroy!

    respond_with_day(phase)
  end

  private

  # Justification speeches belong to a revote round, so they are only ever created by the timeline.
  def speech_params
    permitted = params.require(:breakdown_speech).permit(:speaker_seat, :kind)
    permitted.merge(kind: MANUAL_KINDS.include?(permitted[:kind]) ? permitted[:kind] : MANUAL_KINDS.first)
  end
end
