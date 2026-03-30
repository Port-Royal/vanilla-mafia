class UserGrant < ApplicationRecord
  belongs_to :user
  belongs_to :grant

  validates :grant_id, uniqueness: { scope: :user_id }

  after_destroy :revoke_podcast_feed_token, if: :subscriber_grant?

  private

  def subscriber_grant?
    grant.code == "subscriber"
  end

  def revoke_podcast_feed_token
    token = user.podcast_feed_token
    token.revoke! if token
  end
end
