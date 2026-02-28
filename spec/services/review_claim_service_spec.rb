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

    it "clears the rejection_reason" do
      claim.update!(rejection_reason: "old reason")
      described_class.approve(claim: claim, admin: admin)

      expect(claim.reload.rejection_reason).to be_nil
    end

    it "assigns the player to the claiming user" do
      described_class.approve(claim: claim, admin: admin)

      expect(claim.user.reload.player_id).to eq(claim.player_id)
    end

    context "when claim is not pending" do
      let(:claim) { create(:player_claim, status: "rejected") }

      it "raises ArgumentError" do
        expect { described_class.approve(claim: claim, admin: admin) }
          .to raise_error(ArgumentError, "claim must be pending")
      end
    end

    context "when user is already linked to a different player" do
      let(:other_player) { create(:player) }
      let(:claim) { create(:player_claim, status: "pending") }

      before { claim.user.update!(player: other_player) }

      it "raises ArgumentError" do
        expect { described_class.approve(claim: claim, admin: admin) }
          .to raise_error(ArgumentError, "user already linked to a different player")
      end
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

    context "when claim is not pending" do
      let(:claim) { create(:player_claim, status: "approved") }

      it "raises ArgumentError" do
        expect { described_class.reject(claim: claim, admin: admin, reason: reason) }
          .to raise_error(ArgumentError, "claim must be pending")
      end
    end
  end
end
