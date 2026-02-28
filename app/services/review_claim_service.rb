class ReviewClaimService
  def self.approve(claim:, admin:)
    ActiveRecord::Base.transaction do
      claim.lock!
      raise ArgumentError, "claim must be pending" unless claim.pending?

      claim.update!(status: "approved", reviewed_by: admin, reviewed_at: Time.current, rejection_reason: nil)
      claim.user.update!(player: claim.player)
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
