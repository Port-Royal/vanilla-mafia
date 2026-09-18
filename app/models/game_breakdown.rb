class GameBreakdown < ApplicationRecord
  SEAT_NUMBERS = (1..10)

  ROLES_MODES = {
    open: "open",
    closed: "closed"
  }.freeze

  RESULTS = {
    city: "city",
    mafia: "mafia",
    draw: "draw"
  }.freeze

  enum :roles_mode, ROLES_MODES, default: :open, validate: true
  enum :manual_result, RESULTS, prefix: true, validate: { allow_nil: true }

  belongs_to :author, class_name: "User", inverse_of: :game_breakdowns
  belongs_to :game, optional: true
  has_many :seats, -> { order(:number) }, class_name: "BreakdownSeat", inverse_of: :game_breakdown, dependent: :destroy
  has_many :phases, -> { order(:position) }, class_name: "BreakdownPhase", inverse_of: :game_breakdown, dependent: :destroy
  has_many :speeches, through: :phases
  has_many :vote_rounds, through: :phases

  validates :title, presence: true

  scope :ordered, -> { order(played_on: :desc, created_at: :desc, id: :desc) }

  after_create :create_seats_and_zero_round

  private

  def create_seats_and_zero_round
    participations = participations_by_seat
    SEAT_NUMBERS.each { |number| seats.create!(seat_attributes(number, participations[number])) }
    AppendBreakdownPhaseService.start(breakdown: self)
  end

  def participations_by_seat
    return {} unless game

    game.game_participations.includes(:player).where.not(seat: nil).index_by(&:seat)
  end

  def seat_attributes(number, participation)
    return { number: number } unless participation

    { number: number, name: participation.player.name, player: participation.player, role_code: participation.role_code }
  end
end
