class GameParticipation < ApplicationRecord
  belongs_to :game
  belongs_to :player
  belongs_to :role, foreign_key: :role_code, primary_key: :code, optional: true

  enum :status, { alive: 0, killed_by_mafia: 1, voted_out: 2, banned: 3 }, default: :alive

  normalizes :role_code, with: ->(v) { v.presence }
  # The protocol form posts one select per seat, blanks included, as strings.
  normalizes :best_move_seats, with: lambda { |seats|
    Array(seats).compact_blank.map { |seat| Integer(seat.to_s, 10, exception: false) || seat }.presence
  }

  validates :game, :player, presence: true
  validates :player_id, uniqueness: { scope: :game_id }
  validates :plus, :minus, numericality: true, allow_nil: true
  validates :best_move, numericality: true, allow_nil: true
  validates :seat, numericality: { in: 1..10, only_integer: true }, allow_nil: true
  validates :seat, uniqueness: { scope: :game_id }, allow_nil: true
  validates :best_move_seats, best_move_seats: { excluding: :seat }

  def total
    (plus || 0) - (minus || 0) + (best_move || 0)
  end

  def result
    return nil if game.in_progress? || role_code.blank?

    case game.result
    when "peace_victory"
      return "win" if [ "peace", "sheriff" ].include?(role_code)
    when "mafia_victory"
      return "win" if [ "mafia", "don" ].include?(role_code)
    end

    "lose"
  end
end
