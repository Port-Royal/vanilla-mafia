# frozen_string_literal: true

class PlayerDisputesController < ApplicationController
  before_action :authenticate_user!

  def new
    @player = Player.find_by!(slug: params[:player_slug])
  end

  def create
    @player = Player.find_by!(slug: params[:player_slug])
    dispute_params = params.require(:dispute).permit(:evidence, :selfie, documents: [])
    result = DisputePlayerService.call(
      user: current_user,
      player: @player,
      evidence: dispute_params[:evidence],
      selfie: dispute_params[:selfie],
      documents: dispute_params[:documents]
    )

    if result.success
      redirect_to player_path(@player), notice: t("player_disputes.create.pending")
    else
      redirect_to player_path(@player), alert: t("player_disputes.create.errors.#{result.error}")
    end
  end
end
