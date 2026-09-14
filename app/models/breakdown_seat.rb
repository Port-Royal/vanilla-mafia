class BreakdownSeat < ApplicationRecord
  belongs_to :game_breakdown, inverse_of: :seats
  belongs_to :player, optional: true
  belongs_to :role, foreign_key: :role_code, primary_key: :code, optional: true

  normalizes :name, with: ->(value) { value.strip.presence }
  normalizes :role_code, with: ->(value) { value.presence }

  validates :number, numericality: { in: GameBreakdown::SEAT_NUMBERS, only_integer: true },
                     uniqueness: { scope: :game_breakdown_id }
end
