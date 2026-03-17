class PlayerAward < ApplicationRecord
  belongs_to :player
  belongs_to :award
  belongs_to :competition, optional: true

  validates :player, :award, presence: true
  validates :award_id, uniqueness: { scope: [ :player_id, :competition_id ] }

  scope :ordered, -> { order(position: :asc) }
end
