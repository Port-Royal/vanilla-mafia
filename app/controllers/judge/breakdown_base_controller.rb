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

  def load_editor_data
    @timeline = GameBreakdown::Timeline.new(@breakdown)
    @roles = Role.all
    @players = Player.order(:name)
  end

  def render_editor_streams
    load_editor_data
    render "judge/breakdowns/editor_streams", formats: [ :turbo_stream ]
  end
end
