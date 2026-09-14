class BreakdownPhase < ApplicationRecord
  NIGHT_OUTCOMES = {
    kill: "kill",
    miss: "miss"
  }.freeze

  enum :night_outcome, NIGHT_OUTCOMES, validate: { allow_nil: true }

  belongs_to :game_breakdown, inverse_of: :phases
  has_many :night_actions, class_name: "BreakdownNightAction", inverse_of: :breakdown_phase, dependent: :destroy
  # Speeches are destroyed before vote rounds: justification speeches reference their round.
  has_many :speeches, -> { order(:position) }, class_name: "BreakdownSpeech", inverse_of: :breakdown_phase, dependent: :destroy
  has_many :vote_rounds, -> { order(:number) }, class_name: "BreakdownVoteRound", inverse_of: :breakdown_phase, dependent: :destroy

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :game_breakdown_id }
  validates :killed_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true }, allow_nil: true
  validates :killed_seat, presence: true, if: :kill?
  validates :killed_seat, absence: true, unless: :kill?
  validates :night_outcome, absence: true, if: :day?

  def zero_round?
    position == 0
  end

  def night?
    !position.nil? && position.odd?
  end

  def day?
    !position.nil? && position.even?
  end
end
