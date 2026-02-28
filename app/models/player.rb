class Player < ApplicationRecord
  has_many :ratings, dependent: :restrict_with_error
  has_many :games, through: :ratings
  has_many :player_awards, dependent: :destroy
  has_many :awards, through: :player_awards
  has_many :player_claims, dependent: :destroy
  has_one :user, dependent: :nullify
  has_one_attached :photo

  validates :name, presence: true

  def claimed?
    user.present?
  end

  def claimed_by?(check_user)
    user == check_user
  end

  scope :ordered, -> { order(position: :asc, name: :asc) }

  scope :ranked, -> {
    order(
      Arel.sql("total_rating DESC, wins_count DESC, games_count DESC"),
      name: :asc
    )
  }

  scope :with_stats_for_season, ->(season) {
    joins(ratings: :game)
      .where(games: { season: season })
      .group(:id)
      .select(
        "players.*",
        "COUNT(ratings.id) AS games_count",
        "SUM(CASE WHEN ratings.win THEN 1 ELSE 0 END) AS wins_count",
        "SUM(COALESCE(ratings.plus, 0) - COALESCE(ratings.minus, 0) + COALESCE(ratings.best_move, 0)) AS total_rating"
      )
  }
end
