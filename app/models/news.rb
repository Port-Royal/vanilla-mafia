class News < ApplicationRecord
  belongs_to :author, class_name: "User"
  belongs_to :game, optional: true

  has_rich_text :content

  enum :status, { draft: "draft", published: "published" }

  validates :title, presence: true
  validates :status, presence: true

  scope :recent, -> { order(Arel.sql("published_at IS NULL, published_at DESC, id DESC")) }
  scope :for_game, ->(game) { where(game:) }
  scope :by_author, ->(user) { where(author: user) }

  def publish!
    update!(status: :published, published_at: Time.current)
  end
end
