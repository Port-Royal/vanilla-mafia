class BreakdownSpeech < ApplicationRecord
  KINDS = {
    regular: "regular",
    farewell: "farewell",
    justification: "justification"
  }.freeze

  enum :kind, KINDS, validate: true

  belongs_to :breakdown_phase, inverse_of: :speeches
  belongs_to :breakdown_vote_round, optional: true, inverse_of: :justification_speeches
  has_many :moves, -> { order(:position) }, class_name: "BreakdownMove", inverse_of: :breakdown_speech, dependent: :destroy

  validates :speaker_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :breakdown_vote_round, presence: true, if: :justification?
  validates :breakdown_vote_round, absence: true, unless: :justification?
  validate :phase_is_day, if: :breakdown_phase
  validate :vote_round_in_same_phase, if: -> { breakdown_phase && breakdown_vote_round }

  private

  def phase_is_day
    errors.add(:breakdown_phase, :must_be_day) unless breakdown_phase.day?
  end

  def vote_round_in_same_phase
    errors.add(:breakdown_vote_round, :must_belong_to_phase) unless breakdown_vote_round.breakdown_phase == breakdown_phase
  end
end
