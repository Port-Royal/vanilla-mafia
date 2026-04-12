class Player < ApplicationRecord
  include Sluggable
  slug_source :name

  has_many :game_participations, dependent: :restrict_with_error
  has_many :games, through: :game_participations
  has_many :player_awards, dependent: :destroy
  has_many :awards, through: :player_awards
  has_many :player_claims, dependent: :destroy
  has_many :news_player_mentions, dependent: :destroy
  has_many :mentioning_news, through: :news_player_mentions, source: :news
  has_one :user, dependent: :nullify
  has_one_attached :photo

  validates :name, presence: true, uniqueness: true

  def claimed?
    user.present?
  end

  def claimed_by?(check_user)
    user == check_user
  end

  DEFAULT_PHOTO_PATH = "/img/nophoto.jpg".freeze

  scope :ordered, -> { order(position: :asc, name: :asc) }

  scope :ranked, -> {
    order(
      Arel.sql("total_rating DESC, wins_count DESC, games_count DESC"),
      name: :asc
    )
  }

  scope :with_stats_for_competition, ->(competition) {
    with_aggregated_stats.where(games: { competition_id: competition.subtree_ids })
  }

  scope :with_aggregated_stats, -> {
    joins(game_participations: :game)
      .group(:id)
      .select(
        "players.*",
        "COUNT(game_participations.id) AS games_count",
        "SUM(CASE WHEN game_participations.win THEN 1 ELSE 0 END) AS wins_count",
        "ROUND(SUM(COALESCE(game_participations.plus, 0) - COALESCE(game_participations.minus, 0) + COALESCE(game_participations.best_move, 0)), 2) AS total_rating"
      )
  }
end
