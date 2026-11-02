class GamesController < ApplicationController
  include GameOverlayLoading

  def show
    @game = Game.includes(competition: :parent).find_by!(slug: params[:slug])
    @participations = @game.game_participations.includes(:player, :role).order(Arel.sql("seat IS NULL"), seat: :asc, id: :asc)
  end

  def overlay
    load_game_overlay(Game.find_by!(slug: params[:slug]))
    render layout: "overlay"
  end
end
