class PodcastFeedToken < ApplicationRecord
  belongs_to :user

  has_secure_token

  validates :user_id, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end
end
