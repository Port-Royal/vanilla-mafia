require "rails_helper"

RSpec.describe "Podcast::Episodes" do
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:published_episode) { create(:episode, status: "published", published_at: Time.current) }
  let_it_be(:draft_episode) { create(:episode, status: "draft") }

  describe "GET /podcast/episodes" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/podcast/episodes"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      before { sign_in user }

      it "returns not found" do
        get "/podcast/episodes"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as subscriber" do
      before { sign_in subscriber }

      it "returns success" do
        get "/podcast/episodes"
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as admin" do
      before { sign_in admin }

      it "returns success" do
        get "/podcast/episodes"
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /podcast/episodes/:id" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      before { sign_in user }

      it "returns not found" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as subscriber" do
      before { sign_in subscriber }

      it "returns success for published episode" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
