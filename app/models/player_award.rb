class PlayerAward < ApplicationRecord
  belongs_to :player
  belongs_to :award

  validates :player, :award, presence: true
  validates :award_id, uniqueness: { scope: [ :player_id, :season ] }

  scope :ordered, -> { order(position: :asc) }
end
