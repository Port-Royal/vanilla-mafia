class Game < ApplicationRecord
  has_many :game_participations, dependent: :destroy
  has_many :players, through: :game_participations

  validates :season, :series, :game_number, presence: true, numericality: { only_integer: true }
  validates :game_number, uniqueness: { scope: [ :season, :series ] }

  scope :for_season, ->(season) { where(season: season) }
  scope :ordered, -> { order(played_on: :asc, series: :asc, game_number: :asc) }

  def self.available_seasons
    distinct.order(:season).pluck(:season)
  end

  def full_name
    parts = [ played_on, "Сезон #{season}", "Серия #{series}", "Игра #{game_number}", name ].compact
    parts.join(" ")
  end

  def in_season_name
    "Серия #{series} Игра #{game_number}"
  end
end
