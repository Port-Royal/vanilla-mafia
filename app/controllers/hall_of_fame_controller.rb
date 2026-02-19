class HallOfFameController < ApplicationController
  def show
    @player_awards = PlayerAward.includes(:player, :award).where(award: Award.for_players).ordered.load
    @staff_awards = PlayerAward.includes(:player, :award).where(award: Award.for_staff).ordered.load
  end
end
