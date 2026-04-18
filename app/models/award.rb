class Award < ApplicationRecord
  ICON_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/svg+xml].freeze
  MAX_ICON_SIZE = 1.megabyte

  has_many :player_awards, dependent: :restrict_with_error
  has_many :players, through: :player_awards
  has_one_attached :icon

  validates :title, presence: true
  validate :validate_icon, if: -> { icon.attached? }

  scope :for_players, -> { where(staff: false) }
  scope :for_staff, -> { where(staff: true) }
  scope :ordered, -> { order(position: :asc) }

  private

  def validate_icon
    unless icon.content_type.in?(ICON_CONTENT_TYPES)
      errors.add(:icon, :content_type)
    end

    if icon.byte_size > MAX_ICON_SIZE
      errors.add(:icon, :file_size, count: MAX_ICON_SIZE / 1.megabyte)
    end
  end
end
