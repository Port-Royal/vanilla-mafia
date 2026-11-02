# Tells a per-table overlay which game is current at its table, so the page can reload onto a new game.
# Public, like the overlay itself: the message carries only a game id.
class TableOverlayChannel < ApplicationCable::Channel
  def self.stream_name(table)
    "table_overlay:#{table}"
  end

  def self.broadcast_current(table)
    game = Game.current_at_table(table)
    ActionCable.server.broadcast(stream_name(table), { game_id: game ? game.id : nil })
  end

  def subscribed
    table = params[:table].to_s
    return reject unless table.match?(/\A[1-9]\d*\z/)

    stream_from self.class.stream_name(table)
  end
end
