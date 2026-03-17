class Game < ApplicationRecord
  RESULTS = {
    in_progress: "in_progress",
    peace_victory: "peace_victory",
    mafia_victory: "mafia_victory"
  }.freeze

  enum :result, RESULTS, validate: true

  belongs_to :competition
  has_many :game_participations, dependent: :destroy
  before_validation :derive_season_and_series_from_competition
  has_many :news, dependent: :nullify
  has_many :players, through: :game_participations

  validates :season, :series, :game_number, presence: true, numericality: { only_integer: true }
  validates :result, presence: true
  validates :game_number, uniqueness: { scope: :competition_id }

  scope :for_competition, ->(competition) { where(competition: competition) }
  scope :for_season, ->(season) { where(season: season) }
  scope :ordered, -> { order(played_on: :asc, series: :asc, game_number: :asc) }

  def self.available_seasons
    distinct.order(:season).pluck(:season)
  end

  def full_name
    parts = [ played_on, competition.parent&.name, competition.name, "#{I18n.t('common.game')} #{game_number}", name ].compact
    parts.join(" ")
  end

  def in_season_name
    "#{competition.name} #{I18n.t('common.game')} #{game_number}"
  end

  private

  def derive_season_and_series_from_competition
    return if competition.nil?

    self.season = competition.legacy_season if season.blank?
    self.series = competition.legacy_series if series.blank?
  end
end
