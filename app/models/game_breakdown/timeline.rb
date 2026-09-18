# Replays a breakdown's phases in order and derives what is not stored:
# alive seats, phase labels, speech order, voting outcomes, expected next steps, rule warnings and the game result.
class GameBreakdown::Timeline
  MAFIA_ROLES = %w[mafia don].freeze
  DRAW_NIGHTS = 3
  FINAL_THREE = 3

  Elimination = Data.define(:seat, :reason)
  Nomination = Data.define(:actor_seat, :target_seat)
  ExpectedStep = Data.define(:kind, :seats)
  NextPhase = Data.define(:position, :kind, :farewell_seat, :speech_order)
  RoundResult = Data.define(:round, :candidates, :tally, :outcome, :leaders, :eliminated) do
    # A revote tied among all of its candidates: the next round is a lift (4.4.13.3).
    def full_revote_tie?
      outcome == :tie && round.revote? && leaders.size == candidates.size
    end
  end
  PhaseState = Data.define(
    :phase, :label, :alive_at_start, :alive_at_end, :eliminations, :starter, :speech_order, :farewell_seat,
    :nominations, :candidates, :vote_rounds, :voting_cancelled, :expected_steps
  ) do
    def voting_cancelled?
      voting_cancelled
    end
  end

  attr_reader :phases

  def initialize(breakdown)
    @breakdown = breakdown
    @phases = replay
    @computed_result = compute_result
  end

  def state_for(phase)
    phases.find { |state| state.phase.id == phase.id }
  end

  def result
    @computed_result || @breakdown.manual_result
  end

  def result_computed?
    !@computed_result.nil?
  end

  def finished?
    !result.nil?
  end

  def warnings
    @warnings ||= GameBreakdown::Timeline::Warnings.new(@breakdown, phases).all
  end

  def warnings_for(record)
    warnings_by_record.fetch(record, [])
  end

  # The zero round a breakdown opens with: every seat speaks, whatever the result.
  def opening_phase
    day_step(0, previous_day: nil, farewell_seat: nil, alive: GameBreakdown::SEAT_NUMBERS.to_a)
  end

  def next_phase
    return if finished?

    last = phases.last
    position = last.phase.position + 1
    return NextPhase.new(position: position, kind: :night, farewell_seat: nil, speech_order: []) if last.phase.day?

    day_step(position, previous_day: phases.reverse.find { |state| state.phase.day? }, farewell_seat: night_killed_seat(last), alive: last.alive_at_end)
  end

  private

  def day_step(position, previous_day:, farewell_seat:, alive:)
    starter = day_starter(previous_day, alive)
    NextPhase.new(position: position, kind: :day, farewell_seat: farewell_seat, speech_order: alive.rotate(alive.index(starter)))
  end

  def warnings_by_record
    @warnings_by_record ||= warnings.group_by(&:record)
  end

  def replay
    alive = GameBreakdown::SEAT_NUMBERS.to_a
    previous_state = nil
    previous_day = nil

    loaded_phases.map do |phase|
      state = phase.night? ? night_state(phase, alive) : day_state(phase, alive, previous_state, previous_day)
      alive = state.alive_at_end
      previous_day = state if phase.day?
      previous_state = state
    end
  end

  def loaded_phases
    @breakdown.phases.includes(:night_actions, speeches: :moves, vote_rounds: %i[votes moves])
  end

  def night_state(phase, alive)
    eliminations = night_eliminations(phase, alive)
    PhaseState.new(
      phase: phase, label: label_for(phase, alive), alive_at_start: alive, alive_at_end: alive - eliminations.map(&:seat),
      eliminations: eliminations, starter: nil, speech_order: [], farewell_seat: nil,
      nominations: [], candidates: [], vote_rounds: [], voting_cancelled: false, expected_steps: []
    )
  end

  def night_eliminations(phase, alive)
    return [] unless phase.kill? && alive.include?(phase.killed_seat)

    [ Elimination.new(seat: phase.killed_seat, reason: :night_kill) ]
  end

  def day_state(phase, alive, previous_state, previous_day)
    DayReplay.new(
      phase,
      alive: alive,
      starter: day_starter(previous_day, alive),
      farewell_seat: night_killed_seat(previous_state),
      label: label_for(phase, alive)
    ).state
  end

  def day_starter(previous_day, alive)
    return GameBreakdown::SEAT_NUMBERS.first unless previous_day

    alive.find { |seat| seat > previous_day.starter } || alive.first
  end

  def night_killed_seat(state)
    return unless state && state.phase.night?

    state.eliminations.map(&:seat).first
  end

  def label_for(phase, alive)
    return I18n.t("game_breakdowns.timeline.zero_round") if phase.zero_round?
    return I18n.t("game_breakdowns.timeline.night", number: (phase.position + 1) / 2) if phase.night?
    return I18n.t("game_breakdowns.timeline.final_three") if alive.size == FINAL_THREE

    I18n.t("game_breakdowns.timeline.round", alive: alive.size)
  end

  def compute_result
    roles = @breakdown.seats.pluck(:number, :role_code).to_h
    return if roles.value?(nil)

    mafia = roles.select { |_, code| MAFIA_ROLES.include?(code) }.keys
    nights = []

    phases.each do |state|
      alive = state.alive_at_end
      mafia_alive = (alive & mafia).size
      return "city" if mafia_alive.zero?
      return "mafia" if mafia_alive >= alive.size - mafia_alive
      next unless state.phase.night?

      nights << state
      return "draw" if draw?(nights)
    end

    nil
  end

  # Draw: nobody left the game through three consecutive nights (and the days between them).
  def draw?(nights)
    return false if nights.size < DRAW_NIGHTS

    nights[-DRAW_NIGHTS].alive_at_start.size == nights.last.alive_at_end.size
  end
end
