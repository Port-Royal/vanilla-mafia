# Collects non-blocking rule warnings for a replayed breakdown; they never block saving.
class GameBreakdown::Timeline::Warnings
  REQUIRED_ROLES = %w[mafia don sheriff].freeze

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

  # Open roles mode needs the mafia, the don and the sheriff to derive checks and the result.
  def role_warnings
    return [] unless @breakdown.open?

    (REQUIRED_ROLES - role_seats.keys).map do |role|
      GameBreakdown::Timeline::Warning.new(code: :"missing_#{role}", record: @breakdown)
    end
  end

  def role_seats
    @role_seats ||= @breakdown.seats.group_by(&:role_code).transform_values { |seats| seats.map(&:number) }
  end
end
