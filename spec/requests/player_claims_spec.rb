# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlayerClaimsController do
  describe "POST /players/:player_id/claim" do
    let_it_be(:player) { create(:player) }

    context "when not signed in" do
      it "redirects to sign in" do
        post player_claim_path(player)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      context "when claim requires approval" do
        let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: true) }

        it "creates a pending claim" do
          expect { post player_claim_path(player) }
            .to change(PlayerClaim, :count).by(1)
        end

        it "sets claim status to pending" do
          post player_claim_path(player)

          expect(PlayerClaim.last.status).to eq("pending")
        end

        it "redirects with pending notice" do
          post player_claim_path(player)

          expect(response).to redirect_to(player_path(player))
          expect(flash[:notice]).to eq(I18n.t("player_claims.create.pending"))
        end
      end

      context "when claim does not require approval" do
        let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: false) }

        it "creates an approved claim" do
          expect { post player_claim_path(player) }
            .to change(PlayerClaim, :count).by(1)
        end

        it "sets claim status to approved" do
          post player_claim_path(player)

          expect(PlayerClaim.last.status).to eq("approved")
        end

        it "links player to user" do
          post player_claim_path(player)

          expect(user.reload.player).to eq(player)
        end

        it "redirects with approved notice" do
          post player_claim_path(player)

          expect(response).to redirect_to(player_path(player))
          expect(flash[:notice]).to eq(I18n.t("player_claims.create.approved"))
        end
      end

      context "when user is admin" do
        let(:user) { create(:user, admin: true) }
        let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: true) }

        it "creates an approved claim" do
          post player_claim_path(player)

          expect(PlayerClaim.last.status).to eq("approved")
        end

        it "redirects with approved notice" do
          post player_claim_path(player)

          expect(response).to redirect_to(player_path(player))
          expect(flash[:notice]).to eq(I18n.t("player_claims.create.approved"))
        end
      end

      context "when user already has a claimed player" do
        let(:other_player) { create(:player) }

        before { user.update!(player: other_player) }

        it "does not create a claim" do
          expect { post player_claim_path(player) }
            .not_to change(PlayerClaim, :count)
        end

        it "redirects with alert" do
          post player_claim_path(player)

          expect(response).to redirect_to(player_path(player))
          expect(flash[:alert]).to eq(I18n.t("player_claims.create.errors.already_has_player"))
        end
      end

      context "when player is already claimed by another user" do
        before do
          other_user = create(:user)
          other_user.update!(player: player)
        end

        it "does not create a claim" do
          expect { post player_claim_path(player) }
            .not_to change(PlayerClaim, :count)
        end

        it "redirects with alert" do
          post player_claim_path(player)

          expect(response).to redirect_to(player_path(player))
          expect(flash[:alert]).to eq(I18n.t("player_claims.create.errors.player_already_claimed"))
        end
      end

      context "when a claim already exists for this user and player" do
        before { create(:player_claim, user: user, player: player) }

        it "does not create another claim" do
          expect { post player_claim_path(player) }
            .not_to change(PlayerClaim, :count)
        end

        it "redirects with alert" do
          post player_claim_path(player)

          expect(response).to redirect_to(player_path(player))
          expect(flash[:alert]).to eq(I18n.t("player_claims.create.errors.claim_already_exists"))
        end
      end
    end
  end
end
