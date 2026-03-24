class PlaybackPosition < ApplicationRecord
  belongs_to :user
  belongs_to :episode

  validates :position_seconds, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :episode_id, uniqueness: { scope: :user_id }
end
