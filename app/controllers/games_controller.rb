class GamesController < ApplicationController
  def show
    @game = Game.includes(competition: :parent).find_by!(slug: params[:slug])
    @participations = @game.game_participations.includes(:player, :role).order(Arel.sql("seat IS NULL"), seat: :asc, id: :asc)
  end

  def overlay
    @game = Game.find_by!(slug: params[:slug])
    @participations_by_seat = @game.game_participations.includes(:player, :role).index_by(&:seat)
    render layout: "overlay"
  end
end
