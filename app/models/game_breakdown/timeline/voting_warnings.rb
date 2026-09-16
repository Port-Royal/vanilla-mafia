# Warnings for a day's vote rounds and votes.
class GameBreakdown::Timeline::VotingWarnings
  ZERO_ROUND_LIFT_FORBIDDEN = [ 5, 10 ].freeze
  LIFT_FORBIDDEN_CANDIDATES = 3
  LIFT_FORBIDDEN_ALIVE = 9
  FIRST_ROUND = 1

  def initialize(state)
    @state = state
    @phase = state.phase
    @first_round_after_removal = removal_points.min
  end

  def all
    @state.vote_rounds.each_with_index.flat_map do |result, index|
      round_warnings(result, index) + result.round.votes.filter_map { |vote| vote_warning(vote, result) }
    end
  end

  private

  def round_warnings(result, index)
    [ single_nominee_warning(result, index), removal_warning(result), lift_warning(result), unexpected_round_warning(result, index) ].compact
  end

  # Zero round with a single nominee has no voting (4.4.11).
  def single_nominee_warning(result, index)
    return unless index.zero? && @phase.zero_round? && @state.candidates.one?

    warning(:zero_round_single_nominee_voting, result.round, rule: "4.4.11")
  end

  # A removal cancels the day's voting (4.4.15); every round held after it is warned.
  def removal_warning(result)
    return if @first_round_after_removal.nil? || result.round.number < @first_round_after_removal

    warning(:voting_after_removal, result.round, rule: "4.4.15")
  end

  # Regular speeches precede every round, a justification speech precedes its round, a removal inside a round
  # affects the rounds after it. Farewell speeches are skipped: they belong to seats that already left.
  def removal_points
    speech_points = @phase.speeches.filter_map { |speech| speech_point(speech) if !speech.farewell? && removal?(speech.moves) }
    round_points = @phase.vote_rounds.filter_map { |round| round.number + 1 if removal?(round.moves) }
    speech_points + round_points
  end

  def speech_point(speech)
    return FIRST_ROUND unless speech.justification?

    @phase.vote_rounds.find { |round| round.id == speech.breakdown_vote_round_id }.number
  end

  def removal?(moves)
    moves.any? { |move| move.removal? && @state.alive_at_start.include?(move.actor_seat) }
  end

  # Lift is forbidden with 5 or 10 candidates in the zero round (4.4.16), 3 candidates with 9 alive (4.4.17),
  # or more than half of alive players as candidates (4.4.18).
  def lift_warning(result)
    return unless result.round.lift?

    rule = lift_forbidden_rule(result.candidates.size, @state.alive_at_start.size)
    warning(:lift_forbidden, result.round, rule: rule) if rule
  end

  def lift_forbidden_rule(candidates, alive)
    return "4.4.16" if @phase.zero_round? && ZERO_ROUND_LIFT_FORBIDDEN.include?(candidates)
    return "4.4.17" if candidates == LIFT_FORBIDDEN_CANDIDATES && alive == LIFT_FORBIDDEN_ALIVE

    "4.4.18" if candidates * 2 > alive
  end

  def unexpected_round_warning(result, index)
    return if result.candidates.any? && result.round.kind == expected_kind(index)

    warning(:unexpected_vote_round, result.round)
  end

  # The main round opens the voting; a tie leads to a revote, or to a lift round once a revote ties among all its candidates.
  def expected_kind(index)
    return "main" if index.zero?

    @state.vote_rounds[index - 1].full_revote_tie? ? "lift" : "revote"
  end

  def vote_warning(vote, result)
    return GameBreakdown::Timeline::Warning.for_seat(:eliminated_actor, vote, vote.voter_seat) unless @state.alive_at_start.include?(vote.voter_seat)
    return if result.round.lift? || result.candidates.empty? || result.candidates.include?(vote.candidate_seat)

    GameBreakdown::Timeline::Warning.for_seat(:non_candidate_vote, vote, vote.candidate_seat)
  end

  def warning(code, record, rule: nil)
    GameBreakdown::Timeline::Warning.new(code: code, record: record, rule: rule)
  end
end
