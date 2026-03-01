class GamesController < ApplicationController
  def show
    @game = Game.find(params[:id])
    @participations = @game.game_participations.includes(:player, :role)
  end
end
