class BreakdownNightAction < ApplicationRecord
  KINDS = {
    mafia_shot: "mafia_shot",
    don_check: "don_check",
    sheriff_check: "sheriff_check"
  }.freeze

  enum :kind, KINDS, validate: true

  belongs_to :breakdown_phase, inverse_of: :night_actions

  validates :actor_seat, :target_seat, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true }, allow_nil: true
  validate :phase_is_open_night, if: :breakdown_phase

  private

  def phase_is_open_night
    errors.add(:breakdown_phase, :must_be_night) unless breakdown_phase.night?
    errors.add(:breakdown_phase, :must_be_open_roles_mode) unless breakdown_phase.game_breakdown.open?
  end
end
