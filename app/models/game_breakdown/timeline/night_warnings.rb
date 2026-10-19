# Warnings for a night phase: the kill and, in open roles mode, the recorded shots and checks.
class GameBreakdown::Timeline::NightWarnings
  def initialize(state, role_seats:)
    @state = state
    @role_seats = role_seats
  end

  def all
    [ kill_warning ].compact + @state.phase.night_actions.flat_map { |action| [ actor_warning(action), target_warning(action) ].compact }
  end

  private

  def kill_warning
    eliminated_warning(:eliminated_target, @state.phase, @state.phase.killed_seat)
  end

  # A shot is made by its recorded actor; a check by the seat holding the don / sheriff role.
  def actor_warning(action)
    return eliminated_warning(:eliminated_actor, action, action.actor_seat) if action.mafia_shot?

    eliminated_warning(:eliminated_checker, action, @role_seats.fetch(BreakdownNightAction::CHECKER_ROLES.fetch(action.kind), []).first)
  end

  # A shot needs a player at the table; a check may target one who has already left.
  def target_warning(action)
    eliminated_warning(:eliminated_target, action, action.target_seat) if action.mafia_shot?
  end

  def eliminated_warning(code, record, seat)
    return if seat.nil? || @state.alive_at_start.include?(seat)

    GameBreakdown::Timeline::Warning.for_seat(code, record, seat)
  end
end
