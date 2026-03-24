class Episode < ApplicationRecord
  has_one_attached :audio

  enum :status, { draft: "draft", published: "published" }

  validates :title, presence: true
  validates :status, presence: true

  scope :recent, -> { order(Arel.sql("published_at IS NULL, published_at DESC, id DESC")) }

  def publish!
    update!(status: :published, published_at: Time.current)
  end
end
