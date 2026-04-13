class News < ApplicationRecord
  include Sluggable
  slug_source :title

  SLUG_TITLE_LIMIT = 80

  belongs_to :author, class_name: "User"
  belongs_to :competition, optional: true
  belongs_to :game, optional: true

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  has_many :player_mentions, class_name: "NewsPlayerMention", dependent: :destroy
  has_many :mentioned_players, through: :player_mentions, source: :player

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
    via_game = visible.joins(game: :game_participations).where(game_participations: { player_id: player.id })
    via_mention = visible.joins(:player_mentions).where(news_player_mentions: { player_id: player.id })
    visible.where(id: via_game).or(visible.where(id: via_mention)).distinct.recent
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

  def truncated_content(max_length)
    return content if content.blank?

    plain_text = content.body.to_plain_text
    return content if plain_text.length <= max_length

    html = content.body.to_html
    doc = Nokogiri::HTML.fragment(html)
    result_length = 0
    kept = []

    doc.children.each do |node|
      text_length = node.text.length
      break if result_length + text_length > max_length && kept.any?

      kept << node.to_html
      result_length += text_length
    end

    ActionText::Content.new(kept.join)
  end

  def truncated?(max_length)
    return false if content.blank?

    content.body.to_plain_text.length > max_length
  end

  private

  def slug_base
    "#{slug_date.strftime('%Y-%m-%d')}-#{slug_title_part}"
  end

  def slug_date
    published_at || created_at || Time.current
  end

  def slug_title_part
    transliterated = CyrillicTransliterator.call(title.to_s).parameterize
    truncated = transliterated.truncate(SLUG_TITLE_LIMIT, separator: "-", omission: "").delete_suffix("-")
    truncated.presence || SecureRandom.hex(Sluggable::TAIL_BYTES)
  end

  def content_length_within_limit
    return if content.blank?

    plain_text_length = content.body.to_plain_text.length
    if plain_text_length > MAX_CONTENT_LENGTH
      errors.add(:content, :too_long, count: MAX_CONTENT_LENGTH)
    end
  end
end
