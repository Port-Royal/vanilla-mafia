class ReviewClaimService
  def self.approve(claim:, admin:)
    ActiveRecord::Base.transaction do
      claim.lock!
      raise ArgumentError, "claim must be pending" unless claim.pending?

      user = claim.user
      user.lock!

      raise ArgumentError, "user already linked to a different player" if user.player_id.present? && user.player_id != claim.player_id

      claim.update!(status: "approved", reviewed_by: admin, reviewed_at: Time.current, rejection_reason: nil)
      user.update!(player: claim.player)
    end
  end

  def self.reject(claim:, admin:, reason:)
    ActiveRecord::Base.transaction do
      claim.lock!
      raise ArgumentError, "claim must be pending" unless claim.pending?

      claim.update!(status: "rejected", reviewed_by: admin, reviewed_at: Time.current, rejection_reason: reason)
    end
  end
end
