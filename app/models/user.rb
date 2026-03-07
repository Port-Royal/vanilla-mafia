class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  belongs_to :player, optional: true
  has_many :player_claims, dependent: :destroy
  has_many :news, foreign_key: :author_id, inverse_of: :author, dependent: :destroy

  enum :role, { user: "user", judge: "judge", admin: "admin" }

  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :player_id, uniqueness: true, allow_nil: true
  validates :role, presence: true

  def can_manage_protocols?
    admin? || judge?
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

  def pending_dispute?
    player_claims.disputes.pending.exists?
  end
end
