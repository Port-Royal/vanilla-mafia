class Avo::Actions::ApproveClaim < Avo::BaseAction
  self.name = "Approve Claim"
  self.visible = ->(resource:, view:, **) { view == :show && resource.record.pending? }

  def handle(records:, **_args)
    errored = false

    records.each do |claim|
      if claim.dispute?
        ReviewClaimService.approve_dispute(claim: claim, admin: current_user)
      else
        ReviewClaimService.approve(claim: claim, admin: current_user)
      end
    rescue ArgumentError => e
      errored = true
      error(e.message)
    end

    unless errored
      succeed("Claim approved successfully")
      reload
    end
  end
end
