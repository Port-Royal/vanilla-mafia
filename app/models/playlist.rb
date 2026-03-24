class Playlist < ApplicationRecord
  has_many :playlist_episodes, -> { order(:position) }, dependent: :destroy, inverse_of: :playlist
  has_many :episodes, -> { order("playlist_episodes.position ASC") }, through: :playlist_episodes

  validates :title, presence: true
end
