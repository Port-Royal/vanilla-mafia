# Collects non-blocking rule warnings for a replayed breakdown; they never block saving.
class GameBreakdown::Timeline::Warnings
  ROLE_COUNTS = { "mafia" => 2, "don" => 1, "sheriff" => 1 }.freeze

  def initialize(breakdown, phases)
    @breakdown = breakdown
    @phases = phases
  end

  def all
    role_warnings + @phases.flat_map { |state| phase_warnings(state) }
  end

  private

  def phase_warnings(state)
    return GameBreakdown::Timeline::NightWarnings.new(state, role_seats: role_seats).all if state.phase.night?

    GameBreakdown::Timeline::DayWarnings.new(state, zero_round: @phases.first).all +
      GameBreakdown::Timeline::VotingWarnings.new(state).all
  end

  # Open roles mode needs two mafia members, the don and the sheriff to derive checks and the result.
  def role_warnings
    return [] unless @breakdown.open?

    ROLE_COUNTS.filter_map do |role, expected|
      count = role_seats.fetch(role, []).size
      next if count == expected

      code = count < expected ? :"missing_#{role}" : :"too_many_#{role}"
      GameBreakdown::Timeline::Warning.new(code: code, record: @breakdown, details: { count: count, expected: expected })
    end
  end

  def role_seats
    @role_seats ||= @breakdown.seats.group_by(&:role_code).transform_values { |seats| seats.map(&:number) }
  end
end
