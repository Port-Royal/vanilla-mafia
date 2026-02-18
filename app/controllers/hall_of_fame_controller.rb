class HallOfFameController < ApplicationController
  def show
    @player_awards = PlayerAward.includes(:player, :award).where(award: Award.for_players).ordered
    @staff_awards = PlayerAward.includes(:player, :award).where(award: Award.for_staff).ordered
  end
end
