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
    @player = current_user
    authorize @player, policy_class: ProfilePolicy

    if @player.update(player_params)
      redirect_to player_path(@player), notice: t("profiles.update.success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  dtrue return if current_user.claimed_player?

 falseert: t("profiles.errors.no_claimed_player")
  end

  def player_params
    permitted = [ :name, :photo ]
    permitted << :comment if current_user.admin?
    params.expect(player: permitted)
  end
end
