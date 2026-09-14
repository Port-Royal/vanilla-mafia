class BreakdownVote < ApplicationRecord
  belongs_to :breakdown_vote_round, inverse_of: :votes

  validates :voter_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true },
                         uniqueness: { scope: :breakdown_vote_round_id }
  validates :candidate_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true }, unless: :lift_round?
  validates :candidate_seat, absence: true, if: :lift_round?
  validates :for_lift, inclusion: { in: [ true, false ] }, if: :lift_round?
  validate :for_lift_absent, unless: :lift_round?

  private

  def lift_round?
    !breakdown_vote_round.nil? && breakdown_vote_round.lift?
  end

  def for_lift_absent
    errors.add(:for_lift, :present) unless for_lift.nil?
  end
end
