class Award < ApplicationRecord
  has_many :player_awards, dependent: :restrict_with_error
  has_many :players, through: :player_awards
  has_one_attached :icon

  validates :title, presence: true

  scope :for_players, -> { where(staff: false) }
  scope :for_staff, -> { where(staff: true) }
  scope :ordered, -> { order(position: :asc) }
end
