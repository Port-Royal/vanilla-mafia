class ReviewClaimService
  def self.approve(claim:, admin:)
    ActiveRecord::Base.transaction do
      claim.update!(status: "approved", reviewed_by: admin, reviewed_at: Time.current)
      claim.user.update!(player: claim.player)
    end
  end

  def self.reject(claim:, admin:, reason:)
    claim.update!(status: "rejected", reviewed_by: admin, reviewed_at: Time.current, rejection_reason: reason)
  end
end
