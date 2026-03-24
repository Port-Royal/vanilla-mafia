require "rails_helper"

RSpec.describe "Podcast::Episodes" do
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:published_episode) do
    create(:episode, title: "First Episode", description: "A great episode",
           status: "published", published_at: Time.current)
  end
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

      it "displays published episode titles" do
        get "/podcast/episodes"
        expect(response.body).to include(published_episode.title)
      end

      it "does not display draft episodes" do
        get "/podcast/episodes"
        expect(response.body).not_to include(draft_episode.title)
      end

      it "links to episode show page" do
        get "/podcast/episodes"
        expect(response.body).to include(podcast_episode_path(published_episode))
      end

      it "displays published_at date" do
        get "/podcast/episodes"
        expect(response.body).to include(I18n.l(published_episode.published_at, format: :short))
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

      it "displays the episode title" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include(published_episode.title)
      end

      it "displays the episode description" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include(published_episode.description)
      end

      it "displays published_at date" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include(I18n.l(published_episode.published_at, format: :short))
      end

      it "includes audio player placeholder" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include("audio-player-placeholder")
      end

      it "links back to episodes list" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include(podcast_episodes_path)
      end

      it "includes saved position as data attribute" do
        create(:playback_position, user: subscriber, episode: published_episode, position_seconds: 90)
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include('data-saved-position="90"')
      end

      it "defaults saved position to zero when none exists" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include('data-saved-position="0"')
      end
    end
  end
end
