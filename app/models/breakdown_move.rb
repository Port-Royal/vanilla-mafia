class BreakdownMove < ApplicationRecord
  # Move catalogue: kind => attributes that must be filled for that kind.
  REQUIRED_FIELDS = {
    "sheriff_reveal_table" => [],
    "sheriff_reveal_to_player" => %i[target_seat],
    "check_claim" => %i[claimed_color night_number],
    "nomination" => %i[target_seat],
    "check_request" => %i[target_seat],
    "split_break" => [],
    "protection" => %i[target_seat],
    "best_move" => %i[best_move_seats],
    "removal" => %i[removal_reason],
    "other" => %i[text]
  }.freeze

  CLAIMED_COLORS = {
    red: "red",
    black: "black"
  }.freeze

  REMOVAL_REASONS = {
    fouls: "fouls",
    technical_fouls: "technical_fouls",
    disqualification: "disqualification"
  }.freeze

  BEST_MOVE_SEATS_COUNT = (1..3)

  enum :kind, REQUIRED_FIELDS.keys.index_by(&:itself), validate: true
  enum :claimed_color, CLAIMED_COLORS, prefix: true, validate: { allow_nil: true }
  enum :removal_reason, REMOVAL_REASONS, prefix: true, validate: { allow_nil: true }

  belongs_to :breakdown_speech, optional: true, inverse_of: :moves
  belongs_to :breakdown_vote_round, optional: true, inverse_of: :moves

  before_validation :default_actor_to_speaker

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :actor_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true }
  validates :target_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true }, allow_nil: true
  validates :night_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :exactly_one_context
  validate :kind_required_fields
  validate :best_move_seats_shape, unless: -> { best_move_seats.nil? }

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

  def best_move_seats_shape
    errors.add(:best_move_seats, :invalid) unless valid_best_move_seats?
  end

  def valid_best_move_seats?
    best_move_seats.is_a?(Array) &&
      BEST_MOVE_SEATS_COUNT.cover?(best_move_seats.size) &&
      best_move_seats.uniq.size == best_move_seats.size &&
      best_move_seats.all? { |seat| seat.is_a?(Integer) && GameBreakdown::SEAT_NUMBERS.cover?(seat) }
  end
end
