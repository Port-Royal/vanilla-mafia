class GameParticipation < ApplicationRecord
  belongs_to :game
  belongs_to :player
  belongs_to :role, foreign_key: :role_code, primary_key: :code, optional: true

  normalizes :role_code, with: ->(v) { v.presence }

  validates :game, :player, presence: true
  validates :player_id, uniqueness: { scope: :game_id }
  validates :plus, :minus, numericality: true, allow_nil: true
  validates :best_move, numericality: true, allow_nil: true
  validates :seat, numericality: { in: 1..10, only_integer: true }, allow_nil: true
  validates :seat, uniqueness: { scope: :game_id }, allow_nil: true

  def total
    (plus || 0) - (minus || 0) + (best_move || 0)
  end
end
