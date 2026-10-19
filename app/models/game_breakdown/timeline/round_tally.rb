# Tallies one vote round against its candidates and alive voters.
class GameBreakdown::Timeline::RoundTally
  def initialize(round, candidates:, voters:)
    @round = round
    @candidates = candidates
    @voters = voters
  end

  def result
    return build(tally: {}, outcome: :pending, leaders: [], eliminated: []) if @candidates.empty? || votes_by_voter.empty?

    @round.lift? ? lift_result : candidate_result
  end

  private

  # The round stays pending until every alive player has a ballot: a player who did not vote is counted for the
  # last nominee (4.4.9) only once the judge records it, so no outcome appears while the votes are being entered.
  # Votes for non-candidates are ignored.
  def candidate_result
    tally = @candidates.index_with { [] }
    (@voters & votes_by_voter.keys).each do |voter|
      choice = votes_by_voter[voter].candidate_seat
      tally[choice] << voter if tally.key?(choice)
    end
    return build(tally: tally, outcome: :pending, leaders: [], eliminated: []) if missing_voters.any?

    most_votes = tally.values.map(&:size).max
    leaders = @candidates.select { |seat| tally[seat].size == most_votes }
    single_leader = leaders.one?
    build(tally: tally, outcome: single_leader ? :eliminated : :tie, leaders: leaders, eliminated: single_leader ? leaders : [])
  end

  # Lift passes when strictly more than half of alive players vote for it; then every candidate leaves.
  # Every lift ballot is a vote for it: a player who does not raise a hand has none.
  def lift_result
    supporters = @voters & votes_by_voter.keys
    passed = supporters.size * 2 > @voters.size
    build(
      tally: { for: supporters },
      outcome: passed ? :lift_passed : :lift_failed,
      leaders: [],
      eliminated: passed ? @candidates : []
    )
  end

  # Votes by seats that are not alive are ignored; a round with none from alive voters is still pending.
  def votes_by_voter
    @votes_by_voter ||= @round.votes.select { |vote| @voters.include?(vote.voter_seat) }.index_by(&:voter_seat)
  end

  def missing_voters
    @voters - votes_by_voter.keys
  end

  def build(tally:, outcome:, leaders:, eliminated:)
    GameBreakdown::Timeline::RoundResult.new(
      round: @round, candidates: @candidates, tally: tally, outcome: outcome, leaders: leaders, eliminated: eliminated,
      missing_voters: missing_voters
    )
  end
end
