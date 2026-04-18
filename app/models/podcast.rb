class Podcast < ApplicationRecord
  COVER_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_COVER_SIZE = 5.megabytes

  has_one_attached :cover

  validates :title, presence: true
  validates :author, presence: true
  validates :description, presence: true
  validates :language, presence: true
  validate :validate_cover, if: -> { cover.attached? }

  def self.instance
    first || create!(
      title: "Vanilla Mafia",
      author: "Vanilla Mafia",
      description: "Подкаст клуба спортивной мафии Vanilla Mafia",
      language: "ru"
    )
  end

  private

  def validate_cover
    unless cover.content_type.in?(COVER_CONTENT_TYPES)
      errors.add(:cover, :content_type)
    end

    if cover.byte_size > MAX_COVER_SIZE
      errors.add(:cover, :file_size, count: MAX_COVER_SIZE / 1.megabyte)
    end
  end
end
