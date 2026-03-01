class Avo::Actions::RejectClaim < Avo::BaseAction
  self.name = "Reject Claim"
  self.visible = -> { view.show? && resource.record.pending? }

  def fields
    field :rejection_reason, as: :text
  end

  def handle(records:, fields:, **_args)
    errored = false

    records.each do |claim|
      ReviewClaimService.reject(claim: claim, admin: current_user, reason: fields[:rejection_reason])
    rescue ArgumentError => e
      errored = true
      error(e.message)
    end

    unless errored
      succeed("Claim rejected successfully")
      reload
    end
  end
end
