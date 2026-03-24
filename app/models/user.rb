class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  belongs_to :player, optional: true
  has_many :player_claims, dependent: :destroy
  has_many :news, foreign_key: :author_id, inverse_of: :author, dependent: :restrict_with_exception
  has_many :user_grants, dependent: :destroy
  has_many :grants, through: :user_grants

  enum :role, { user: "user", judge: "judge", editor: "editor", admin: "admin" }

  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :player_id, uniqueness: true, allow_nil: true
  validates :role, presence: true

  def has_grant?(code)
    grants.exists?(code: code)
  end

  def admin?
    has_grant?("admin")
  end

  def judge?
    has_grant?("judge")
  end

  def editor?
    has_grant?("editor")
  end

  def can_manage_protocols?
    admin? || judge?
  end

  def can_manage_news?
    admin? || editor?
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
