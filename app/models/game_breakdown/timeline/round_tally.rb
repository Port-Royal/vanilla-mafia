# Tallies one vote round against its candidates and alive voters.
class GameBreakdown::Timeline::RoundTally
  def initialize(round, candidates:, voters:)
    @round = round
    @candidates = candidates
    @voters = voters
  end

  def result
    return build(tally: {}, outcome: :pending, leaders: [], eliminated: []) if @candidates.empty? || @round.votes.empty?

    @round.lift? ? lift_result : candidate_result
  end

  private

  # A player who did not vote is counted for the last nominee (4.4.9); votes for non-candidates are ignored.
  def candidate_result
    tally = @candidates.index_with { [] }
    @voters.each do |voter|
      choice = votes_by_voter.key?(voter) ? votes_by_voter[voter].candidate_seat : @candidates.last
      tally[choice] << voter if tally.key?(choice)
    end

    most_votes = tally.values.map(&:size).max
    leaders = @candidates.select { |seat| tally[seat].size == most_votes }
    single_leader = leaders.one?
    build(tally: tally, outcome: single_leader ? :eliminated : :tie, leaders: leaders, eliminated: single_leader ? leaders : [])
  end

  # Lift passes when strictly more than half of alive players vote for it; then every candidate leaves.
  def lift_result
    supporters = @voters.select { |voter| votes_by_voter.key?(voter) && votes_by_voter[voter].for_lift }
    passed = supporters.size * 2 > @voters.size
    build(
      tally: { for: supporters, against: @voters - supporters },
      outcome: passed ? :lift_passed : :lift_failed,
      leaders: [],
      eliminated: passed ? @candidates : []
    )
  end

  def votes_by_voter
    @votes_by_voter ||= @round.votes.index_by(&:voter_seat)
  end

  def build(tally:, outcome:, leaders:, eliminated:)
    GameBreakdown::Timeline::RoundResult.new(
      round: @round, candidates: @candidates, tally: tally, outcome: outcome, leaders: leaders, eliminated: eliminated
    )
  end
end
