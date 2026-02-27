class PlayerClaim < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :user
  belongs_to :player
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :player_id }
  validate :user_has_no_claimed_player, on: :create
  validate :player_not_already_claimed, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def self.require_approval?
    Rails.application.config.player_claims.require_approval
  end

  private

  def user_has_no_claimed_player
    return unless user
    return if user.player_id.nil?

    errors.add(:user, :already_claimed)
  end

  def player_not_already_claimed
    return unless player_id

    errors.add(:player, :already_claimed) if User.exists?(player_id: player_id)
  end
end
