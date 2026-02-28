# frozen_string_literal: true

class ProfilesController < ApplicationController
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :ensure_claimed_player

  def edit
    @player = current_user.player
    authorize @player, policy_class: ProfilePolicy
  end

  def update
    @player = current_user.player
    authorize @player, policy_class: ProfilePolicy

    if @player.update(player_params)
      redirect_to player_path(@player), notice: t("profiles.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def ensure_claimed_player
    return if current_user.claimed_player?

    redirect_to root_path, alert: t("profiles.errors.no_claimed_player")
  end

  def player_params
    params.expect(player: [ :name, :comment, :photo ])
  end
end
