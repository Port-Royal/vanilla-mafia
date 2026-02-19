class HallOfFameController < ApplicationController
  def show
    result = HallOfFameService.call
    @player_awards = result.player_awards
    @staff_awards = result.staff_awards
  end
end
