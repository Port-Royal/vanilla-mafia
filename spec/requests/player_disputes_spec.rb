require "rails_helper"

RSpec.describe PlayerDisputesController do
  let_it_be(:player) { create(:player) }

  describe "GET /players/:player_id/dispute/new" do
    context "when not signed in" do
      before { get new_player_dispute_path(player) }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before do
        sign_in user
        get new_player_dispute_path(player)
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /players/:player_id/dispute" do
    context "when not signed in" do
      before { post player_dispute_path(player), params: { dispute: { evidence: "This is my profile" } } }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when player is claimed by another user and params are valid" do
      let(:user) { create(:user) }
      let(:owner) { create(:user, player: player) }

      before { owner }

      it "redirects to the player page with a success notice" do
        sign_in user
        post player_dispute_path(player), params: { dispute: { evidence: "This is my profile" } }

        expect(response).to redirect_to(player_path(player))
        expect(flash[:notice]).to eq(I18n.t("player_disputes.create.pending"))
      end
    end

    context "when user already has a player" do
      let_it_be(:own_player) { create(:player) }
      let(:user) { create(:user, player: own_player) }

      before do
        sign_in user
        post player_dispute_path(player), params: { dispute: { evidence: "This is my profile" } }
      end

      it "redirects to the player page with an alert" do
        expect(response).to redirect_to(player_path(player))
        expect(flash[:alert]).to eq(I18n.t("player_disputes.create.errors.already_has_player"))
      end
    end

    context "when player is not claimed" do
      let(:unclaimed_player) { create(:player) }
      let(:user) { create(:user) }

      before do
        sign_in user
        post player_dispute_path(unclaimed_player), params: { dispute: { evidence: "This is my profile" } }
      end

      it "redirects to the player page with an alert" do
        expect(response).to redirect_to(player_path(unclaimed_player))
        expect(flash[:alert]).to eq(I18n.t("player_disputes.create.errors.player_not_claimed"))
      end
    end
  end
end
