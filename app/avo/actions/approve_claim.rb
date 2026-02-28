class Avo::Actions::ApproveClaim < Avo::BaseAction
  self.name = "Approve Claim"
  self.visible = ->(resource:, view:, **) { view == :show && resource.record.pending? }

  def handle(records:, **_args)
    errored = false

    records.each do |claim|
      ReviewClaimService.approve(claim: claim, admin: current_user)
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
