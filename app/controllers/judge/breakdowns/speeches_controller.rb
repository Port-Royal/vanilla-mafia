class Judge::Breakdowns::SpeechesController < Judge::BreakdownBaseController
  MANUAL_KINDS = %w[regular farewell].freeze

  before_action :set_breakdown

  def create
    phase = @breakdown.phases.find(params[:breakdown_phase_id])
    speech = phase.speeches.new(speech_params)
    speech.position = next_position(phase.speeches)
    return render_editor_error(speech.errors.full_messages.to_sentence) unless speech.save

    respond_with_phase(phase)
  end

  # The gist of a speech changes nothing else on the page, so a stream request gets no content back and the
  # textarea the judge is typing in is left alone.
  def update
    @breakdown.speeches.find(params[:id]).update!(params.require(:breakdown_speech).permit(:summary))

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to editor_path }
    end
  end

  def destroy
    speech = @breakdown.speeches.find(params[:id])
    phase = speech.breakdown_phase
    speech.destroy!

    respond_with_phase(phase)
  end

  private

  # Justification speeches belong to a revote round, so they are only ever created by the timeline.
  def speech_params
    permitted = params.require(:breakdown_speech).permit(:speaker_seat, :kind)
    permitted.merge(kind: MANUAL_KINDS.include?(permitted[:kind]) ? permitted[:kind] : MANUAL_KINDS.first)
  end
end
