require "rails_helper"

RSpec.describe ProfilesController do
  describe "GET /profile/edit" do
    context "when user is not signed in" do
      before { get edit_profile_path }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user has no claimed player" do
      let_it_be(:user) { create(:user) }

      before do
        sign_in user
        get edit_profile_path
      end

      it "redirects to root" do
        expect(response).to redirect_to(root_path)
      end

      it "sets an alert flash" do
        expect(flash[:alert]).to eq(I18n.t("profiles.errors.no_claimed_player"))
      end
    end

    context "when user has a claimed player" do
      let_it_be(:player) { create(:player, name: "Алексей") }
      let_it_be(:user) { create(:user, player: player) }

      before do
        sign_in user
        get edit_profile_path
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the edit form" do
        expect(response.body).to include(I18n.t("profiles.edit.title"))
      end

      it "renders the player name in the form" do
        expect(response.body).to include("Алексей")
      end
    end
  end

  describe "PATCH /profile" do
    context "when user is not signed in" do
      before { patch profile_path, params: { player: { name: "Новое имя" } } }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user has no claimed player" do
      let_it_be(:user) { create(:user) }

      before do
        sign_in user
        patch profile_path, params: { player: { name: "Новое имя" } }
      end

      it "redirects to root" do
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user has a claimed player" do
      let(:player) { create(:player, name: "Старое имя") }
      let(:user) { create(:user, player: player) }

      before { sign_in user }

      context "with valid params" do
        before { patch profile_path, params: { player: { name: "Новое имя", comment: "Привет" } } }

        it "updates the player" do
          expect(player.reload.name).to eq("Новое имя")
        end

        it "updates the comment" do
          expect(player.reload.comment).to eq("Привет")
        end

        it "redirects to player show page" do
          expect(response).to redirect_to(player_path(player))
        end

        it "sets a notice flash" do
          expect(flash[:notice]).to eq(I18n.t("profiles.update.success"))
        end
      end

      context "with invalid params" do
        before { patch profile_path, params: { player: { name: "" } } }

        it "does not update the player" do
          expect(player.reload.name).to eq("Старое имя")
        end

        it "re-renders the edit form" do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "renders validation errors" do
          expect(response.body).to include(I18n.t("profiles.edit.title"))
        end
      end
    end
  end
end
