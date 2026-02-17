class Game < ApplicationRecord
  has_many :ratings, dependent: :destroy
  has_many :players, through: :ratings

  validates :season, :series, :game_number, presence: true, numericality: { only_integer: true }
  validates :game_number, uniqueness: { scope: [ :season, :series ] }

  scope :for_season, ->(season) { where(season: season) }
  scope :ordered, -> { order(played_on: :asc, series: :asc, game_number: :asc) }

  def full_name
    parts = [ played_on&.to_s, "Сезон #{season}", "Серия #{series}", "Игра #{game_number}", name ].compact
    parts.join(" ")
  end

  def in_season_name
    "Серия #{series} Игра #{game_number}"
  end
end
