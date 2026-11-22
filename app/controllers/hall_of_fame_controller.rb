class HallOfFameController < ApplicationController
  def show
    result = HallOfFameService.call
    if helpers.new_design?
      @player_entries = result.player_entries
      @staff_entries = result.staff_entries
      render "hall_of_fame/redesign/show"
    else
      @player_awards = result.player_awards
      @staff_awards = result.staff_awards
    end
  end
end
