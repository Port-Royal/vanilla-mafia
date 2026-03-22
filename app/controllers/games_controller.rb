class GamesController < ApplicationController
  def show
    @game = Game.includes(competition: :parent).find(params[:id])
    @participations = @game.game_participations.includes(:player, :role).order(Arel.sql("seat IS NULL"), seat: :asc, id: :asc)
  end

  def overlay
    @game = Game.find(params[:id])
    @participations = @game.game_participations.includes(:player, :role).order(seat: :asc, id: :asc)
    render layout: "overlay"
  end
end
