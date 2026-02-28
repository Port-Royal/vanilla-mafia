class ReviewClaimService
  def self.approve(claim:, admin:)
    raise ArgumentError, "claim must be pending" unless claim.pending?

    ActiveRecord::Base.transaction do
      claim.update!(status: "approved", reviewed_by: admin, reviewed_at: Time.current, rejection_reason: nil)
      claim.user.update!(player: claim.player)
    end
  end

  def self.reject(claim:, admin:, reason:)
    raise ArgumentError, "claim must be pending" unless claim.pending?

    claim.update!(status: "rejected", reviewed_by: admin, reviewed_at: Time.current, rejection_reason: reason)
  end
end
