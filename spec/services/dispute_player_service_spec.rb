require "rails_helper"

RSpec.describe DisputePlayerService do
  describe ".call" do
    let(:user) { create(:user) }
    let(:player) { create(:player) }
    let(:evidence) { "This is my profile, here is proof." }

    context "when user already has a claimed player" do
      let(:existing_player) { create(:player) }
      let(:user) { create(:user, player: existing_player) }
      let(:owner) { create(:user, player: player) }

      before { owner }

      it "returns failure with :already_has_player error" do
        result = described_class.call(user: user, player: player, evidence: evidence)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:already_has_player)
      end
    end

    context "when player is not claimed" do
      it "returns failure with :player_not_claimed error" do
        result = described_class.call(user: user, player: player, evidence: evidence)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:player_not_claimed)
      end
    end

    context "when user already has a pending dispute" do
      let(:other_player) { create(:player) }
      let(:owner) { create(:user, player: player) }

      before do
        owner
        create(:user, player: other_player)
        create(:player_claim, :dispute, user: user, player: other_player, status: "pending")
      end

      it "returns failure with :already_pending error" do
        result = described_class.call(user: user, player: player, evidence: evidence)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:already_pending)
      end
    end

    context "when user+player dispute already exists" do
      let(:owner) { create(:user, player: player) }

      before do
        owner
        create(:player_claim, :dispute, user: user, player: player, status: "rejected")
      end

      it "returns failure with :dispute_already_exists error" do
        result = described_class.call(user: user, player: player, evidence: evidence)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:dispute_already_exists)
      end
    end

    context "when all preconditions are met" do
      let(:owner) { create(:user, player: player) }

      before { owner }

      it "creates a pending dispute claim with the evidence" do
        result = described_class.call(user: user, player: player, evidence: evidence)

        expect(result.success).to be true
        expect(result.claim).to be_a(PlayerClaim)
        expect(result.claim.status).to eq("pending")
        expect(result.claim.dispute).to be true
        expect(result.claim.evidence).to eq(evidence)
        expect(result.error).to be_nil
      end

      it "enqueues a DisputeMailer.dispute_filed email" do
        expect { described_class.call(user: user, player: player, evidence: evidence) }
          .to have_enqueued_mail(DisputeMailer, :dispute_filed)
      end
    end

    it "returns a Result" do
      result = described_class.call(user: user, player: player, evidence: evidence)

      expect(result).to be_a(described_class::Result)
    end
  end
end
