# frozen_string_literal: true

class PlayerClaimsController < ApplicationController
  before_action :authenticate_user!

  def create
    player = Player.find(params[:player_id])
    result = ClaimPlayerService.call(user: current_user, player:)

    if result.success
      redirect_back fallback_location: player_path(player),
                    notice: notice_message(result.claim)
    else
      redirect_back fallback_location: player_path(player),
                    alert: t("player_claims.create.errors.#{result.error}")
    end
  end

  private

  def notice_message(claim)
    claim.approved? ? t("player_claims.create.approved") : t("player_claims.create.pending")
  end
end
