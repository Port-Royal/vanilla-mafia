# Shared access control and editor rendering for the game breakdown editor:
# judge or admin grant, behind the `game_breakdown` feature toggle.
class Judge::BreakdownBaseController < ApplicationController
  FEATURE_KEY = "game_breakdown".freeze

  before_action :authenticate_user!
  before_action :require_breakdown_access!

  private

  def require_breakdown_access!
    head :not_found unless current_user.can_manage_protocols? && FeatureToggle.enabled?(FEATURE_KEY)
  end

  def editor_path
    edit_judge_breakdown_path(@breakdown)
  end

  def set_breakdown
    @breakdown = GameBreakdown.find(params[:breakdown_id])
  end

  # An edit can make the timeline expect new blocks, so they are materialised before re-rendering
  # the edited phase and every phase after it — alive counts and labels downstream depend on it.
  def respond_with_phase(phase)
    SyncBreakdownStepsService.call(breakdown: @breakdown)
    @from_position = phase.position
    respond_with_editor
  end

  # Positions only ever grow, so a deletion leaves a gap rather than renumbering the blocks around it.
  # An unsaved record already attached to the collection has no position yet and must not count.
  def next_position(records)
    positions = records.filter_map(&:position)
    positions.empty? ? 0 : positions.max + 1
  end

  def render_editor_error(message)
    load_editor_data
    flash.now[:error] = message
    render "judge/breakdowns/edit", status: :unprocessable_content
  end

  def load_timeline
    @timeline = GameBreakdown::Timeline.new(@breakdown)
  end

  def load_editor_data
    load_timeline
    @roles = Role.all
    @players = Player.order(:name)
  end

  # Turbo clients get the action's own stream template; everything else falls back to a full editor reload.
  def respond_with_editor
    respond_to do |format|
      format.turbo_stream { load_editor_data }
      format.html { redirect_to editor_path }
    end
  end
end
