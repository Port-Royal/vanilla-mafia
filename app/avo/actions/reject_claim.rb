class Avo::Actions::RejectClaim < Avo::BaseAction
  self.name = "Reject Claim"
  self.visible = ->(resource:, view:, **) { view == :show && resource.record.pending? }

  def fields
    field :rejection_reason, as: :text
  end

  def handle(records:, fields:, **_args)
    records.each do |claim|
      ReviewClaimService.reject(claim: claim, admin: current_user, reason: fields[:rejection_reason])
    rescue ArgumentError => e
      error(e.message)
    end

    succeed("Claim rejected successfully")
    reload
  end
end
