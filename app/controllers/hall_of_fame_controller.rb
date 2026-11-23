class HallOfFameController < ApplicationController
  def show
    result = HallOfFameService.call
    @player_entries = result.player_entries
    @staff_entries = result.staff_entries
  end
end
