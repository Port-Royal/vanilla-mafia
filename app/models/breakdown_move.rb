class BreakdownMove < ApplicationRecord
  # Move catalogue: kind => attributes that must be filled for that kind.
  REQUIRED_FIELDS = {
    "sheriff_reveal_table" => [],
    "check_claim" => %i[target_seat claimed_color],
    "nomination" => %i[target_seat],
    "check_request" => %i[target_seat],
    "split_break" => [],
    "protection" => %i[target_seat],
    "best_move" => %i[best_move_seats],
    "foul" => [],
    "removal" => %i[removal_reason],
    "other" => %i[text]
  }.freeze

  # Fields a kind may fill in without needing them; the form shows them next to the required ones.
  OPTIONAL_FIELDS = { "split_break" => %i[target_seat] }.freeze

  CLAIMED_COLORS = {
    red: "red",
    black: "black"
  }.freeze

  REMOVAL_REASONS = {
    fouls: "fouls",
    technical_fouls: "technical_fouls",
    disqualification: "disqualification"
  }.freeze

  BEST_MOVE_SEATS_COUNT = BestMoveSeatsValidator::SEATS_COUNT

  enum :kind, REQUIRED_FIELDS.keys.index_by(&:itself), validate: true
  enum :claimed_color, CLAIMED_COLORS, prefix: true, validate: { allow_nil: true }
  enum :removal_reason, REMOVAL_REASONS, prefix: true, validate: { allow_nil: true }

  belongs_to :breakdown_speech, optional: true, inverse_of: :moves
  belongs_to :breakdown_vote_round, optional: true, inverse_of: :moves

  before_validation :default_actor_to_speaker

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :actor_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true }
  validates :target_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true }, allow_nil: true
  validate :exactly_one_context
  validate :kind_required_fields
  validates :best_move_seats, best_move_seats: true

  private

  def default_actor_to_speaker
    self.actor_seat ||= breakdown_speech.speaker_seat if breakdown_speech
  end

  def exactly_one_context
    return if breakdown_speech.nil? != breakdown_vote_round.nil?

    errors.add(:base, :exactly_one_context)
  end

  def kind_required_fields
    REQUIRED_FIELDS.fetch(kind, []).each do |attribute|
      errors.add(attribute, :blank) if public_send(attribute).blank?
    end
  end
end
