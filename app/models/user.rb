class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable,
         :lockable, :timeoutable, :omniauthable, omniauth_providers: [ :google_oauth2 ]

  belongs_to :player, optional: true
  has_many :player_claims, dependent: :destroy
  has_many :news, foreign_key: :author_id, inverse_of: :author, dependent: :restrict_with_exception
  has_many :user_grants, dependent: :destroy
  has_many :grants, through: :user_grants
  has_many :announcement_dismissals, dependent: :destroy
  has_one :podcast_feed_token, dependent: :destroy

  enum :datetime_format, {
    european_24h: "european_24h",
    iso: "iso",
    us_12h: "us_12h"
  }, default: "european_24h"

  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :password, password_strength: true, if: :password_required?
  validates :player_id, uniqueness: true, allow_nil: true

  scope :telegram_stubs, -> { where(stub_source: "telegram") }

  def self.find_or_create_telegram_stub!(player)
    telegram_stubs.find_by(player_id: player.id) || create_telegram_stub!(player)
  rescue ActiveRecord::RecordNotUnique
    telegram_stubs.find_by!(player_id: player.id)
  end

  def self.create_telegram_stub!(player)
    user = new(
      player: player,
      stub_source: "telegram",
      email: "telegram-#{player.id}@stub.invalid",
      password: SecureRandom.hex(32)
    )
    user.lock_access!(send_instructions: false)
    user
  end
  private_class_method :create_telegram_stub!

  def telegram_stub?
    stub_source == "telegram"
  end

  def active_for_authentication?
    super && !telegram_stub?
  end

  def display_name
    return email unless claimed_player?

    "#{email} (#{player.name})"
  end

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

  def subscriber?
    has_grant?("subscriber")
  end

  def can_manage_protocols?
    admin? || judge?
  end

  def can_manage_news?
    admin? || editor?
  end

  def can_view_help?
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
