class Game < ApplicationRecord
  include Sluggable
  slug_source :game_number

  RESULTS = {
    in_progress: "in_progress",
    peace_victory: "peace_victory",
    mafia_victory: "mafia_victory",
    draw: "draw"
  }.freeze

  enum :result, RESULTS, validate: true

  belongs_to :competition
  has_many :game_participations, dependent: :destroy
  has_many :game_protocol_events, dependent: :destroy
  has_many :news, dependent: :nullify
  has_many :game_breakdowns, dependent: :nullify
  has_many :players, through: :game_participations

  validates :game_number, presence: true, numericality: { only_integer: true }
  validates :result, presence: true
  validates :game_number, uniqueness: { scope: :competition_id }
  validates :table_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :games_total, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :games_total_covers_game_number

  scope :for_competition, ->(competition) { where(competition: competition) }
  scope :ordered, -> { order(played_on: :asc, game_number: :asc) }
  scope :recent, -> { where.not(played_on: nil).order(played_on: :desc, game_number: :desc) }
  scope :finished, -> { where.not(result: "in_progress") }

  CHECK_KINDS = { "don_check" => "don", "sheriff_check" => "sheriff" }.freeze

  BLACK_ROLES = %w[don mafia].freeze

  # Checks give roles away, so viewers get them only while roles are public. A skipped check has no seat.
  def public_checks
    return [] unless roles_public?

    game_protocol_events.where(kind: CHECK_KINDS.keys).order(:position).map do |event|
      { night: event.day_number + 1, kind: CHECK_KINDS.fetch(event.kind), target_seat: event.target_seats.first, result: event.metadata["result"] }
    end
  end

  # A kill shows on the player's tile anyway, so shots are public. The target's team is not.
  def public_shots
    by_night = game_protocol_events.where(kind: %w[shot miss_shot]).order(:position).group_by { |event| event.day_number + 1 }
    by_night.map do |night, events|
      shot = events.find { |event| event.kind == "shot" }
      target = shot ? shot.target_seats.first : nil
      { night:, target_seat: target, team: target && shot_team(target) }
    end
  end

  def current_nominees
    GameProtocolEvent::Nominees.call(game_protocol_events.order(:position))
  end

  def journal_started?
    game_protocol_events.exists?
  end

  def roles_public?
    !(in_progress? && hide_roles?)
  end

  def full_name
    parts = [ played_on, competition.parent&.name, competition.name, "#{I18n.t('common.game')} #{game_number}", name ].compact
    parts.join(" ")
  end

  def in_season_name
    "#{competition.name} #{I18n.t('common.game')} #{game_number}"
  end

  private

  def shot_team(seat)
    return unless roles_public?

    participation = game_participations.find_by(seat:)
    return if participation.nil? || participation.role_code.nil?

    BLACK_ROLES.include?(participation.role_code) ? "black" : "red"
  end

  def slug_base
    return SecureRandom.hex(Sluggable::TAIL_BYTES) unless competition

    "#{competition.slug}-game-#{game_number}"
  end

  def games_total_covers_game_number
    return if games_total.nil? || game_number.nil? || games_total >= game_number

    errors.add(:games_total, :greater_than_or_equal_to, count: game_number)
  end
end
