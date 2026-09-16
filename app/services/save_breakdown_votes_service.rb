# Replaces the ballots of one vote round from the editor's vote table.
# A blank or missing choice means the player did not vote: the row is removed, and the tally falls back
# to the last nominee for that player (4.4.9). An invalid choice is dropped rather than raised on.
class SaveBreakdownVotesService
  def self.call(round:, ballots:)
    new(round, ballots).call
  end

  def initialize(round, ballots)
    @round = round
    @ballots = ballots
  end

  def call
    @ballots.each { |voter_seat, ballot| save_ballot(voter_seat, ballot) }
  end

  private

  def save_ballot(voter_seat, ballot)
    attributes = @round.lift? ? lift_attributes(ballot) : candidate_attributes(ballot)
    vote = @round.votes.find_or_initialize_by(voter_seat: voter_seat)
    return vote.destroy if attributes.nil?

    vote.update(attributes)
  end

  def candidate_attributes(ballot)
    seat = ballot["candidate_seat"].presence
    { candidate_seat: seat } if seat
  end

  def lift_attributes(ballot)
    choice = ballot["for_lift"].presence
    { for_lift: choice } if choice
  end
end
