class PlaybackPosition < ApplicationRecord
  belongs_to :user
  belongs_to :episode

  VALID_SPEEDS = [ 1, 1.25, 1.5, 1.75, 2 ].freeze

  validates :position_seconds, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :playback_speed, inclusion: { in: VALID_SPEEDS }
  validates :episode_id, uniqueness: { scope: :user_id }
end
