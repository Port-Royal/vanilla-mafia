class News < ApplicationRecord
  belongs_to :author, class_name: "User"
  belongs_to :competition, optional: true
  belongs_to :game, optional: true

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  has_many_attached :photos
  has_rich_text :content

  enum :status, { draft: "draft", published: "published" }

  validates :title, presence: true
  validates :status, presence: true

  scope :recent, -> { order(Arel.sql("published_at IS NULL, published_at DESC, id DESC")) }
  scope :for_game, ->(game) { where(game:) }
  scope :for_competition, ->(competition) { where(competition: competition) }
  scope :by_author, ->(user) { where(author: user) }
  scope :mentioning_player, ->(player) {
    published
      .joins(game: :game_participations)
      .where(game_participations: { player_id: player.id })
      .distinct
      .recent
  }

  def publish!
    update!(status: :published, published_at: Time.current)
  end

  def unpublish!
    update!(status: :draft, published_at: nil)
  end
end
