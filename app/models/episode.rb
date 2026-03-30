class Episode < ApplicationRecord
  has_one_attached :audio

  enum :status, { draft: "draft", published: "published" }

  validates :title, presence: true
  validates :status, presence: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  after_save_commit :enqueue_duration_extraction, if: -> { audio.attached? && duration_seconds.nil? }

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
end
