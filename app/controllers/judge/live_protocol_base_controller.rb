# Shared access control for the live protocol: judge or admin grant, behind the `live_protocol` feature toggle.
class Judge::LiveProtocolBaseController < ApplicationController
  FEATURE_KEY = "live_protocol".freeze

  before_action :authenticate_user!
  before_action :require_live_protocol_access!
  before_action :set_game

  private

  def require_live_protocol_access!
    head :not_found unless current_user.can_manage_protocols? && FeatureToggle.enabled?(FEATURE_KEY)
  end

  def set_game
    @game = Game.find_by!(slug: params[:id])
  end
end
