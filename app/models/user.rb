class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  belongs_to :player, optional: true
  has_many :player_claims, dependent: :destroy

  validates :player_id, uniqueness: true, allow_nil: true

  def admin?
    admin
  end

  def claimed_player?
    player_id.present?
  end

  def pending_claim?
    player_claims.pending.exists?
  end

  def pending_claim_for(player)
    player_claims.pending.find_by(player:)
  end
end
