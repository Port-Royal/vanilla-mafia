require "rails_helper"

RSpec.describe ClaimPlayerService do
  describe ".call" do
    let(:user) { create(:user) }
    let(:player) { create(:player) }

    context "when user already has a claimed player" do
      let(:existing_player) { create(:player) }
      let(:user) { create(:user, player: existing_player) }

      it "returns failure with :already_has_player error" do
        result = described_class.call(user: user, player: player)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:already_has_player)
      end
    end

    context "when player is already claimed by another user" do
      before { create(:user, player: player) }

      it "returns failure with :player_already_claimed error" do
        result = described_class.call(user: user, player: player)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:player_already_claimed)
      end
    end

    context "when user has a pending claim for a different player" do
      let(:other_player) { create(:player) }

      before { create(:player_claim, user: user, player: other_player, status: "pending") }

      it "returns failure with :already_pending error" do
        result = described_class.call(user: user, player: player)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:already_pending)
      end
    end

    context "when user already has a pending claim for the player" do
      before { create(:player_claim, user: user, player: player, status: "pending") }

      it "returns failure with :already_pending error" do
        result = described_class.call(user: user, player: player)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:already_pending)
      end
    end

    context "when user has a rejected claim for the player" do
      before { create(:player_claim, user: user, player: player, status: "rejected") }

      it "returns failure with :claim_already_exists error" do
        result = described_class.call(user: user, player: player)

        expect(result.success).to be false
        expect(result.claim).to be_nil
        expect(result.error).to eq(:claim_already_exists)
      end
    end

    context "when approval is required" do
      let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: true) }

      context "when user is not an admin" do
        it "creates a pending claim" do
          result = described_class.call(user: user, player: player)

          expect(result.success).to be true
          expect(result.claim).to be_a(PlayerClaim)
          expect(result.claim.status).to eq("pending")
          expect(result.error).to be_nil
        end

        it "does not assign the player to the user" do
          described_class.call(user: user, player: player)

          expect(user.reload.player_id).to be_nil
        end
      end

      context "when user is an admin" do
        let(:user) { create(:user, admin: true) }

        it "creates an approved claim" do
          result = described_class.call(user: user, player: player)

          expect(result.success).to be true
          expect(result.claim.status).to eq("approved")
          expect(result.error).to be_nil
        end

        it "assigns the player to the user" do
          described_class.call(user: user, player: player)

          expect(user.reload.player_id).to eq(player.id)
        end
      end
    end

    context "when approval is not required" do
      let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: false) }

      it "creates an approved claim" do
        result = described_class.call(user: user, player: player)

        expect(result.success).to be true
        expect(result.claim.status).to eq("approved")
        expect(result.error).to be_nil
      end

      it "assigns the player to the user" do
        described_class.call(user: user, player: player)

        expect(user.reload.player_id).to eq(player.id)
      end
    end

    it "returns a Result" do
      result = described_class.call(user: user, player: player)

      expect(result).to be_a(described_class::Result)
    end
  end
end
