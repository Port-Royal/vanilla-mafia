# Derives a single day phase: nominations, removals, the vote round chain and the blocks the day still expects.
class GameBreakdown::Timeline::DayReplay
  def initialize(phase, alive:, starter:, farewell_seat:, label:)
    @phase = phase
    @alive = alive
    @starter = starter
    @farewell_seat = farewell_seat
    @label = label
  end

  def state
    GameBreakdown::Timeline::PhaseState.new(
      phase: @phase, label: @label, alive_at_start: @alive, alive_at_end: @alive - eliminations.map(&:seat),
      eliminations: eliminations, starter: @starter, speech_order: @alive.rotate(@alive.index(@starter)),
      farewell_seat: @farewell_seat, nominations: nominations, candidates: candidates, vote_rounds: round_results,
      voting_cancelled: voting_cancelled?, expected_steps: expected_steps
    )
  end

  private

  def nominations
    @nominations ||= @phase.speeches.flat_map(&:moves).select(&:nomination?).map do |move|
      GameBreakdown::Timeline::Nomination.new(actor_seat: move.actor_seat, target_seat: move.target_seat)
    end
  end

  def candidates
    @candidates ||= nominations.map(&:target_seat).select { |seat| @alive.include?(seat) }.uniq
  end

  # A removal cancels the day's voting (4.4.15) unless it happens in a farewell speech after the voting result.
  def removed_before_result
    @removed_before_result ||= removed_seats(
      @phase.speeches.reject { |speech| post_vote_farewell?(speech) }.flat_map(&:moves) + @phase.vote_rounds.flat_map(&:moves)
    )
  end

  def removed_after_result
    removed_seats(@phase.speeches.select { |speech| post_vote_farewell?(speech) }.flat_map(&:moves))
  end

  def removed_seats(moves)
    moves.select(&:removal?).map(&:actor_seat).select { |seat| @alive.include?(seat) }.uniq
  end

  def post_vote_farewell?(speech)
    speech.farewell? && speech.speaker_seat != @farewell_seat
  end

  def voting_cancelled?
    removed_before_result.any?
  end

  def eliminations
    @eliminations ||= removals(removed_before_result) +
                      vote_eliminated.map { |seat| GameBreakdown::Timeline::Elimination.new(seat: seat, reason: :vote) } +
                      removals(removed_after_result - removed_before_result - vote_eliminated)
  end

  def removals(seats)
    seats.map { |seat| GameBreakdown::Timeline::Elimination.new(seat: seat, reason: :removal) }
  end

  # Zero round with a single nominee has no voting (4.4.11).
  def voting_allowed?
    !(@phase.zero_round? && candidates.one?)
  end

  def vote_eliminated
    return [] if voting_cancelled? || !voting_allowed? || round_results.empty?

    round_results.last.eliminated
  end

  def round_results
    @round_results ||= begin
      previous = nil
      @phase.vote_rounds.map do |round|
        previous = GameBreakdown::Timeline::RoundTally.new(round, candidates: round_candidates(round, previous), voters: @alive).result
      end
    end
  end

  # main: the day's nominees; revote / lift: the tied seats of the previous round.
  def round_candidates(round, previous)
    return candidates if round.main?
    return [] unless previous && previous.outcome == :tie

    previous.leaders
  end

  def expected_steps
    return [] if voting_cancelled?

    [ voting_step, farewell_step ].compact
  end

  def voting_step
    last = round_results.last
    return main_round_step unless last
    return unless last.outcome == :tie

    kind = last.full_revote_tie? ? :lift_round : :revote_round
    GameBreakdown::Timeline::ExpectedStep.new(kind: kind, seats: last.leaders)
  end

  def main_round_step
    return unless candidates.any? && voting_allowed?

    GameBreakdown::Timeline::ExpectedStep.new(kind: :main_round, seats: candidates)
  end

  def farewell_step
    missing = vote_eliminated - @phase.speeches.select(&:farewell?).map(&:speaker_seat)
    GameBreakdown::Timeline::ExpectedStep.new(kind: :farewell_speeches, seats: missing) if missing.any?
  end
end
