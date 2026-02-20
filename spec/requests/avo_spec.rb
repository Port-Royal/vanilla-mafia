require "rails_helper"

RSpec.describe "Avo admin panel" do
  describe "GET /avo" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/avo"

        expect(response).to redirect_to("/users/sign_in")
      end
    end

    context "when signed in as a non-admin user" do
      let_it_be(:user) { create(:user, admin: false) }

      before { sign_in user }

      it "does not grant access" do
        get "/avo"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as an admin user" do
      let_it_be(:admin) { create(:user, admin: true) }

      before { sign_in admin }

      it "grants access" do
        get "/avo"

        expect(response).to have_http_status(:redirect)

        follow_redirect!

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
