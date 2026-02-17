class Rating < ApplicationRecord
  belongs_to :game
  belongs_to :player
  belongs_to :role, foreign_key: :role_code, primary_key: :code, optional: true

  validates :game, :player, presence: true
  validates :player_id, uniqueness: { scope: :game_id }
  validates :plus, :minus, numericality: true, allow_nil: true
  validates :best_move, numericality: true, allow_nil: true

  def total
    (plus || 0) - (minus || 0) + extra_points
  end

  def extra_points
    0
  end
end
