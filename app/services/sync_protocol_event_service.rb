# Writes the explicit outcome of a journal event to the fields the overlay lives on, once,
# at the moment of the judge's action. Replaying the journal never comes through here.
class SyncProtocolEventService
  RevertForbidden = Class.new(StandardError)

  STATUS_BY_REASON = { "killed" => "killed_by_mafia", "voted" => "voted_out", "removed" => "banned" }.freeze

  def self.apply(event)
    new(event).apply
  end

  def self.revert(event)
    new(event).revert
  end

  def initialize(event)
    @event = event
    @game = event.game
  end

  def apply
    case @event.kind
    when "roles" then write_roles(@event.metadata["roles"])
    when "player_left" then write_statuses(STATUS_BY_REASON.fetch(@event.metadata["reason"]))
    when "player_restored" then write_statuses("alive")
    when "best_move" then write(@event.actor_seat, "best_move_seats", @event.target_seats)
    when "game_finished" then finish_game
    end
  end

  def revert
    case @event.kind
    when "roles" then write_roles(@event.metadata["roles"].transform_values { nil })
    when "player_left" then write_statuses("alive")
    when "player_restored" then write_statuses("banned")
    when "best_move" then write(@event.actor_seat, "best_move_seats", nil)
    when "game_finished" then raise RevertForbidden, "game_finished cannot be reverted"
    end
  end

  private

  def write_roles(role_codes)
    role_codes.each { |seat, role_code| write(seat.to_i, "role_code", role_code) }
  end

  def write_statuses(status)
    @event.target_seats.each { |seat| write(seat, "status", status) }
  end

  def write(seat, field, value)
    @game.game_participations.find_by!(seat:).update!(field => value)
    broadcast(scope: "participation", seat:, field:, value:) if field != "role_code" || @game.roles_public?
  end

  def broadcast(payload)
    ActiveRecord.after_all_transactions_commit { GameProtocolChannel.broadcast_to(@game, payload) }
  end

  def finish_game
    @game.update!(result: @event.metadata["result"])
    ActiveRecord.after_all_transactions_commit { BroadcastOverlayRolesService.call(game: @game) }
  end
end
