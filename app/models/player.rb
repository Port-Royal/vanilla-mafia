class Player < ApplicationRecord
  has_many :ratings, dependent: :restrict_with_error
  has_many :games, through: :ratings
  has_many :player_awards, dependent: :destroy
  has_many :awards, through: :player_awards
  has_one_attached :photo

  validates :name, presence: true

  scope :ordered, -> { order(position: :asc, name: :asc) }

  scope :with_stats_for_season, ->(season) {
    joins(ratings: :game)
      .where(games: { season: season })
      .group(:id)
      .select(
        "players.*",
        "COUNT(ratings.id) AS games_count",
        "SUM(CASE WHEN ratings.win THEN 1 ELSE 0 END) AS wins_count",
        "SUM(ratings.plus - ratings.minus) AS total_rating"
      )
  }
end
