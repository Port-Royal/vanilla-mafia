# One static OBS URL per table: the page shows whatever game is current at the table and reloads
# onto the next one when TableOverlayChannel announces it.
class TableOverlaysController < ApplicationController
  include GameOverlayLoading

  layout "overlay"

  def show
    @table = params[:number].to_i
    game = Game.current_at_table(@table)
    load_game_overlay(game) if game
  end
end
