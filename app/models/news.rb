class News < ApplicationRecord
  belongs_to :author, class_name: "User"
  belongs_to :competition, optional: true
  belongs_to :game, optional: true

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  has_many_attached :photos
  has_rich_text :content

  enum :status, { draft: "draft", published: "published" }

  MAX_CONTENT_LENGTH = 50_000

  validates :title, presence: true
  validates :status, presence: true
  validate :content_length_within_limit

  scope :visible, -> { published.where(published_at: ..Time.current) }
  scope :recent, -> { order(Arel.sql("published_at IS NULL, published_at DESC, id DESC")) }
  scope :drafts_first, -> { order(Arel.sql("published_at IS NOT NULL, published_at DESC, id DESC")) }
  scope :for_game, ->(game) { where(game:) }
  scope :for_competition, ->(competition) { where(competition: competition) }
  scope :by_author, ->(user) { where(author: user) }
  scope :mentioning_player, ->(player) {
    visible
      .joins(game: :game_participations)
      .where(game_participations: { player_id: player.id })
      .distinct
      .recent
  }

  def visible?
    published? && published_at.present? && published_at <= Time.current
  end

  def publish!
    attrs = { status: :published }
    attrs[:published_at] = Time.current if published_at.blank?
    update!(attrs)
  end

  def unpublish!
    update!(status: :draft)
  end

  private

  def content_length_within_limit
    return if content.blank?

    plain_text_length = content.body.to_plain_text.length
    if plain_text_length > MAX_CONTENT_LENGTH
      errors.add(:content, :too_long, count: MAX_CONTENT_LENGTH)
    end
  end
end
