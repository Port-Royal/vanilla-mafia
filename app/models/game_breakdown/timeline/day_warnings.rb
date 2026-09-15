# Warnings for a day phase's speeches and moves.
class GameBreakdown::Timeline::DayWarnings
  TARGETED_KINDS = %w[nomination check_request protection sheriff_reveal_to_player split_break].freeze
  FIRST_DAY_POSITION = 2
  EARLY_LEAVERS_LIMIT = 2

  def initialize(state, zero_round:)
    @state = state
    @phase = state.phase
    @zero_round = zero_round
  end

  def all
    speech_warnings + move_warnings + repeated_nomination_warnings
  end

  private

  def speech_warnings
    @phase.speeches.flat_map { |speech| [ speaker_warning(speech), block_warning(speech) ].compact }
  end

  def speaker_warning(speech)
    return if alive?(speech.speaker_seat) || opening_farewell?(speech)

    warning_for_seat(:eliminated_speaker, speech, speech.speaker_seat)
  end

  # A farewell speech belongs to a seat that left by night kill or vote; a justification speech to a candidate of its round.
  def block_warning(speech)
    if speech.farewell?
      warning_for_seat(:unexpected_farewell, speech, speech.speaker_seat) unless farewell_seats.include?(speech.speaker_seat)
    elsif speech.justification?
      warning_for_seat(:unexpected_justification, speech, speech.speaker_seat) unless justified_seats(speech).include?(speech.speaker_seat)
    end
  end

  def move_warnings
    speech_moves = @phase.speeches.flat_map { |speech| speech.moves.flat_map { |move| speech_move_warnings(move, speech) } }
    round_moves = @phase.vote_rounds.flat_map(&:moves).filter_map { |move| actor_warning(move) }
    speech_moves + round_moves
  end

  def speech_move_warnings(move, speech)
    [ actor_warning(move, speech), target_warning(move), check_claim_warning(move), best_move_warning(move, speech) ].compact
  end

  # The night-killed seat may still act in its own farewell speech.
  def actor_warning(move, speech = nil)
    return if alive?(move.actor_seat)
    return if !speech.nil? && opening_farewell?(speech) && move.actor_seat == speech.speaker_seat

    warning_for_seat(:eliminated_actor, move, move.actor_seat)
  end

  def target_warning(move)
    return unless TARGETED_KINDS.include?(move.kind) && !move.target_seat.nil? && !alive?(move.target_seat)

    warning_for_seat(:eliminated_target, move, move.target_seat)
  end

  def check_claim_warning(move)
    return unless move.check_claim? && move.night_number > nights_passed

    GameBreakdown::Timeline::Warning.new(code: :check_claim_night_out_of_range, record: move, details: { night: move.night_number })
  end

  # More than one nomination by the same player in a day (4.4.2).
  def repeated_nomination_warnings
    nominations = @phase.speeches.flat_map(&:moves).select(&:nomination?)
    nominations.group_by(&:actor_seat).values.flat_map { |moves| moves.drop(1) }.map do |move|
      warning_for_seat(:repeated_nomination, move, move.actor_seat, rule: "4.4.2")
    end
  end

  # Night best move: the first night-killed player, unless two or more players left the zero round (4.5.10, 6.11.4).
  # Day best move: a player leaving the zero round after a split break (4.4.20).
  def best_move_warning(move, speech)
    return unless move.best_move?
    return if @phase.zero_round? ? split_break_farewell?(speech) : first_night_farewell?(speech)

    GameBreakdown::Timeline::Warning.new(code: :best_move_without_right, record: move, rule: @phase.zero_round? ? "4.4.20" : "6.11.4")
  end

  def first_night_farewell?(speech)
    @phase.position == FIRST_DAY_POSITION && opening_farewell?(speech) && @zero_round.eliminations.size < EARLY_LEAVERS_LIMIT
  end

  def split_break_farewell?(speech)
    speech.farewell? && vote_eliminated.include?(speech.speaker_seat) && @phase.speeches.flat_map(&:moves).any?(&:split_break?)
  end

  def opening_farewell?(speech)
    speech.farewell? && speech.speaker_seat == @state.farewell_seat
  end

  def farewell_seats
    [ @state.farewell_seat, *vote_eliminated ]
  end

  def vote_eliminated
    @state.eliminations.select { |elimination| elimination.reason == :vote }.map(&:seat)
  end

  def justified_seats(speech)
    @state.vote_rounds.find { |result| result.round.id == speech.breakdown_vote_round_id }.candidates
  end

  def nights_passed
    @phase.position / 2
  end

  def alive?(seat)
    @state.alive_at_start.include?(seat)
  end

  def warning_for_seat(code, record, seat, rule: nil)
    GameBreakdown::Timeline::Warning.for_seat(code, record, seat, rule: rule)
  end
end
