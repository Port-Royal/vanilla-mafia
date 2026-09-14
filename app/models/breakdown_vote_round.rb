class BreakdownVoteRound < ApplicationRecord
  KINDS = {
    main: "main",
    revote: "revote",
    lift: "lift"
  }.freeze

  enum :kind, KINDS, validate: true

  belongs_to :breakdown_phase, inverse_of: :vote_rounds
  has_many :votes, class_name: "BreakdownVote", inverse_of: :breakdown_vote_round, dependent: :destroy
  has_many :moves, -> { order(:position) }, class_name: "BreakdownMove", inverse_of: :breakdown_vote_round, dependent: :destroy
  has_many :justification_speeches, class_name: "BreakdownSpeech", inverse_of: :breakdown_vote_round, dependent: :destroy

  validates :number, numericality: { only_integer: true, greater_than: 0 },
                     uniqueness: { scope: :breakdown_phase_id }
  validate :phase_is_day, if: :breakdown_phase

  private

  def phase_is_day
    errors.add(:breakdown_phase, :must_be_day) unless breakdown_phase.day?
  end
end
