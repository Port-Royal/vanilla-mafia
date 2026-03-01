# frozen_string_literal: true

class PlayerDisputesController < ApplicationController
  before_action :authenticate_user!

  def new
    @player = Player.find(params[:player_id])
  end

  def create
    @player = Player.find(params[:player_id])
    result = DisputePlayerService.call(
      user: current_user,
      player: @player,
      evidence: params.require(:dispute).permit(:evidence)[:evidence]
    )

    if result.success
      redirect_to player_path(@player), notice: t("player_disputes.create.pending")
    else
      redirect_to player_path(@player), alert: t("player_disputes.create.errors.#{result.error}")
    end
  end
end
