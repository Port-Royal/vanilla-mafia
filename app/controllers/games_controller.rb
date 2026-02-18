class GamesController < ApplicationController
  def show
    @game = Game.find(params[:id])
    @ratings = @game.ratings.includes(:player, :role)
  end
end
