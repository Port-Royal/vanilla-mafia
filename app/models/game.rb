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
  # Each table numbers its games from 1 every day, so a number repeats across days and tables.
  validates :game_number, uniqueness: { scope: [ :competition_id, :played_on, :table_number ], message: :taken_on_day }
  validates :table_number, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :games_total, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :games_total_covers_game_number

  # A per-table overlay reloads onto the table's current game, which these changes can move.
  TABLE_SLOT_ATTRIBUTES = %w[table_number played_on result].freeze

  after_commit :announce_table, on: [ :create, :destroy ]
  after_commit :announce_moved_tables, on: :update

  scope :for_competition, ->(competition) { where(competition: competition) }
  scope :ordered, -> { order(played_on: :asc, game_number: :asc) }
  scope :recent, -> { where.not(played_on: nil).order(played_on: :desc, game_number: :desc) }
  scope :finished, -> { where.not(result: "in_progress") }
  scope :unfinished_from_past_day, -> { in_progress.where(played_on: ...Date.current) }

  # A game without a table number counts as table 1: most evenings run one table and leave the field blank.
  DEFAULT_TABLE = 1

  scope :at_table, ->(number) { where(table_number: number == DEFAULT_TABLE ? [ number, nil ] : number) }

  # The highest number a table has used on a day, nil when it has none yet: numbers restart every day at every table.
  def self.last_number_at(competition_id:, played_on:, table:)
    where(competition_id:, played_on:).at_table(table).maximum(:game_number)
  end

  # The game an overlay of the table shows: the latest started game in progress today, otherwise
  # the last game of today, so the final reveal stays on screen until the next game starts.
  def self.current_at_table(number)
    today = at_table(number).where(played_on: Date.current).order(created_at: :desc, id: :desc)
    today.in_progress.first || today.first
  end

  CHECK_KINDS = { "don_check" => "don", "sheriff_check" => "sheriff" }.freeze

  TEAMS = { "don" => "black", "mafia" => "black", "sheriff" => "red", "peace" => "red" }.freeze

  # Checks give roles away, so viewers get them only while roles are public. A skipped check has no seat.
  def public_checks
    return [] unless roles_public?

    game_protocol_events.where(kind: CHECK_KINDS.keys).order(:position).map do |event|
      target = event.target_seats.first
      { night: event.day_number + 1, kind: CHECK_KINDS.fetch(event.kind), target_seat: target, result: event.metadata["result"], team: target && public_team(target) }
    end
  end

  SANCTION_COUNTERS = { "foul" => :fouls, "tech" => :tech }.freeze

  # Fouls are given out loud at the table, so viewers see them whatever the role setting.
  def public_fouls
    counts = Hash.new { |hash, seat| hash[seat] = { fouls: 0, tech: 0 } }
    game_protocol_events.where(kind: %w[foul tech sanction_cancelled]).order(:position).each do |event|
      seat = event.target_seats.first
      if event.kind == "sanction_cancelled"
        counter = SANCTION_COUNTERS.fetch(event.metadata["sanction"])
        counts[seat][counter] = [ counts[seat][counter] - 1, 0 ].max
      else
        counts[seat][SANCTION_COUNTERS.fetch(event.kind)] += 1
      end
    end
    counts.reject { |_seat, count| count.values.all?(&:zero?) }
  end

  # A kill shows on the player's tile anyway, so shots are public. The target's team comes only
  # while roles are public.
  def public_shots
    by_night = game_protocol_events.where(kind: %w[shot miss_shot]).order(:position).group_by { |event| event.day_number + 1 }
    by_night.map do |night, events|
      shot = events.find { |event| event.kind == "shot" }
      target = shot ? shot.target_seats.first : nil
      { night:, target_seat: target, team: target && public_team(target) }
    end
  end

  def current_nominees
    GameProtocolEvent::Nominees.call(game_protocol_events.order(:position))
  end

  def journal_started?
    game_protocol_events.exists?
  end

  def table_key
    table_number || DEFAULT_TABLE
  end

  def unfinished_from_past_day?
    in_progress? && played_on.present? && played_on < Date.current
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

  def announce_table
    TableOverlayChannel.broadcast_current(table_key)
  end

  def announce_moved_tables
    return unless TABLE_SLOT_ATTRIBUTES.any? { |attribute| saved_change_to_attribute?(attribute) }

    [ table_number_before_last_save || DEFAULT_TABLE, table_key ].uniq.each do |table|
      TableOverlayChannel.broadcast_current(table)
    end
  end

  def public_team(seat)
    return unless roles_public?

    participation = game_participations.find_by(seat:)
    TEAMS[participation.role_code] if participation
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
