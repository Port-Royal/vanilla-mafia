require "rails_helper"

RSpec.describe ReviewClaimService do
  let(:admin) { create(:user, admin: true) }

  describe ".approve" do
    let(:claim) { create(:player_claim, status: "pending") }

    it "updates the claim status to approved" do
      described_class.approve(claim: claim, admin: admin)

      expect(claim.reload.status).to eq("approved")
    end

    it "sets the reviewed_by to the admin" do
      described_class.approve(claim: claim, admin: admin)

      expect(claim.reload.reviewed_by).to eq(admin)
    end

    it "sets the reviewed_at timestamp" do
      described_class.approve(claim: claim, admin: admin)

      expect(claim.reload.reviewed_at).to be_present
    end

    it "assigns the player to the claiming user" do
      described_class.approve(claim: claim, admin: admin)

      expect(claim.user.reload.player_id).to eq(claim.player_id)
    end
  end

  describe ".reject" do
    let(:claim) { create(:player_claim, status: "pending") }
    let(:reason) { "Недостаточно доказательств" }

    it "updates the claim status to rejected" do
      described_class.reject(claim: claim, admin: admin, reason: reason)

      expect(claim.reload.status).to eq("rejected")
    end

    it "sets the reviewed_by to the admin" do
      described_class.reject(claim: claim, admin: admin, reason: reason)

      expect(claim.reload.reviewed_by).to eq(admin)
    end

    it "sets the reviewed_at timestamp" do
      described_class.reject(claim: claim, admin: admin, reason: reason)

      expect(claim.reload.reviewed_at).to be_present
    end

    it "stores the rejection reason" do
      described_class.reject(claim: claim, admin: admin, reason: reason)

      expect(claim.reload.rejection_reason).to eq(reason)
    end

    it "does not assign the player to the user" do
      described_class.reject(claim: claim, admin: admin, reason: reason)

      expect(claim.user.reload.player_id).to be_nil
    end
  end
end
