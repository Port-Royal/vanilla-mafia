class Avo::Actions::ApproveClaim < Avo::BaseAction
  self.name = "Approve Claim"
  self.visible = ->(resource:, view:, **) { view == :show && resource.record.pending? }

  def handle(records:, **_args)
    records.each do |claim|
      ReviewClaimService.approve(claim: claim, admin: current_user)
    rescue ArgumentError => e
      error(e.message)
    end

    succeed("Claim approved successfully")
    reload
  end
end
