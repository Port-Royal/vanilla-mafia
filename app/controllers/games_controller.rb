class GamesController < ApplicationController
  def show
    @game = Game.includes(competition: :parent).find_by!(slug: params[:slug])
    @participations = @game.game_participations.includes(:player, :role).order(Arel.sql("seat IS NULL"), seat: :asc, id: :asc)
  end

  def overlay
    @game = Game.find_by!(slug: params[:slug])
    @participations_by_seat = @game.game_participations.includes(:player, :role).index_by(&:seat)
    @overlay_config = build_overlay_config
    render layout: "overlay"
  end

  private

  def build_overlay_config
    config = {}
    config[:font_size] = clamp_font_size(params[:font_size])
    config[:color] = sanitize_hex_color(params[:color])
    config[:hide_roles] = params[:hide_roles] == "1"
    config[:hide_best_move] = params[:hide_best_move] == "1"
    config[:hide_seats] = params[:hide_seats] == "1"
    config
  end

  def clamp_font_size(value)
    return nil unless value.is_a?(String) && value.match?(/\A\d+\z/)

    value.to_i.clamp(8, 72)
  end

  def sanitize_hex_color(value)
    return nil unless value.is_a?(String) &&
                      value.match?(/\A(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/)

    value.downcase
  end
end
