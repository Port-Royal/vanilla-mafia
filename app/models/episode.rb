class Episode < ApplicationRecord
  has_one_attached :audio

  enum :status, { draft: "draft", published: "published" }

  validates :title, presence: true
  validates :status, presence: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :recent, -> { order(Arel.sql("published_at IS NULL, published_at DESC, id DESC")) }

  def formatted_duration
    return nil unless duration_seconds

    hours, remainder = duration_seconds.divmod(3600)
    minutes, seconds = remainder.divmod(60)

    if hours > 0
      format("%d:%02d:%02d", hours, minutes, seconds)
    else
      format("%d:%02d", minutes, seconds)
    end
  end

  def publish!
    update!(status: :published, published_at: Time.current)
  end
end
