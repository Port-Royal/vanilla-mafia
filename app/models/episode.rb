class Episode < ApplicationRecord
  AUDIO_CONTENT_TYPES = %w[audio/mpeg audio/mp4 audio/x-m4a audio/wav].freeze
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_AUDIO_SIZE = 200.megabytes
  MAX_IMAGE_SIZE = 5.megabytes

  has_one_attached :audio
  has_one_attached :image

  enum :status, { draft: "draft", published: "published" }

  validates :title, presence: true
  validates :status, presence: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :validate_audio, if: -> { audio.attached? }
  validate :validate_image, if: -> { image.attached? }

  after_save_commit :enqueue_duration_extraction, if: -> { audio.attached? && duration_seconds.nil? }

  scope :recent, -> { order(Arel.sql("published_at IS NULL, published_at DESC, id DESC")) }
  scope :visible, -> { published.where(published_at: ..Time.current) }

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

  def extract_duration_from_audio
    return unless audio.attached?
    return if duration_seconds.present?

    audio.open do |tempfile|
      tag = WahWah.open(tempfile.path)
      duration = tag.duration.to_i
      if duration > 0
        self.class.where(id: id, duration_seconds: nil)
                  .update_all(duration_seconds: duration)
      end
    end
  rescue WahWah::WahWahArgumentError
    # Audio file format not supported or corrupted — skip duration extraction
  end

  private

  def enqueue_duration_extraction
    ExtractEpisodeDurationJob.perform_later(self)
  end

  def validate_audio
    unless audio.content_type.in?(AUDIO_CONTENT_TYPES)
      errors.add(:audio, :content_type)
    end

    if audio.byte_size > MAX_AUDIO_SIZE
      errors.add(:audio, :file_size, count: MAX_AUDIO_SIZE / 1.megabyte)
    end
  end

  def validate_image
    unless image.content_type.in?(IMAGE_CONTENT_TYPES)
      errors.add(:image, :content_type)
    end

    if image.byte_size > MAX_IMAGE_SIZE
      errors.add(:image, :file_size, count: MAX_IMAGE_SIZE / 1.megabyte)
    end
  end
end
