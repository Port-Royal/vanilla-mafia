class PlaylistEpisode < ApplicationRecord
  belongs_to :playlist
  belongs_to :episode

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :episode_id, uniqueness: { scope: :playlist_id }
  validates :position, uniqueness: { scope: :playlist_id }
end
