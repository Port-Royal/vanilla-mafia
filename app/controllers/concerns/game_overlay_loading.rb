# What games/overlay.html.erb needs to draw one game, shared by the per-game and the per-table overlay.
module GameOverlayLoading
  extend ActiveSupport::Concern

  private

  def load_game_overlay(game)
    @game = game
    @participations_by_seat = game.game_participations.includes(:player, :role).index_by(&:seat)
    @nominees = game.current_nominees
    @checks = game.public_checks
    @shots = game.public_shots
    @fouls = game.public_fouls
  end
end
