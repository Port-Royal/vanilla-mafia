require "rails_helper"

RSpec.describe "Podcast::Playlists" do
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:playlist) { create(:playlist, title: "Best Of Season 1") }
  let_it_be(:episode_one) do
    create(:episode, title: "Opening Act", status: "published", published_at: 1.day.ago)
  end
  let_it_be(:episode_two) do
    create(:episode, title: "Grand Finale", status: "published", published_at: Time.current)
  end
  let_it_be(:playlist_episode_one) do
    create(:playlist_episode, playlist: playlist, episode: episode_one, position: 1)
  end
  let_it_be(:playlist_episode_two) do
    create(:playlist_episode, playlist: playlist, episode: episode_two, position: 2)
  end

  describe "GET /podcast/playlists" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/podcast/playlists"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      before { sign_in user }

      it "returns not found" do
        get "/podcast/playlists"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as subscriber" do
      before { sign_in subscriber }

      it "returns success" do
        get "/podcast/playlists"
        expect(response).to have_http_status(:ok)
      end

      it "displays playlist titles" do
        get "/podcast/playlists"
        expect(response.body).to include(playlist.title)
      end

      it "links to playlist show page" do
        get "/podcast/playlists"
        expect(response.body).to include(podcast_playlist_path(playlist))
      end

      it "displays episode count" do
        get "/podcast/playlists"
        expect(response.body).to include("2")
      end
    end

    context "when signed in as admin" do
      before { sign_in admin }

      it "returns success" do
        get "/podcast/playlists"
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /podcast/playlists/:id" do
    context "when not signed in" do
      it "redirects to sign in" do
        get "/podcast/playlists/#{playlist.id}"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      before { sign_in user }

      it "returns not found" do
        get "/podcast/playlists/#{playlist.id}"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as subscriber" do
      before { sign_in subscriber }

      it "returns success" do
        get "/podcast/playlists/#{playlist.id}"
        expect(response).to have_http_status(:ok)
      end

      it "displays the playlist title" do
        get "/podcast/playlists/#{playlist.id}"
        expect(response.body).to include(playlist.title)
      end

      it "displays episode titles in order" do
        get "/podcast/playlists/#{playlist.id}"
        body = response.body
        expect(body).to include(episode_one.title)
        expect(body).to include(episode_two.title)
        expect(body.index(episode_one.title)).to be < body.index(episode_two.title)
      end

      it "links to individual episodes" do
        get "/podcast/playlists/#{playlist.id}"
        expect(response.body).to include(podcast_episode_path(episode_one))
        expect(response.body).to include(podcast_episode_path(episode_two))
      end

      it "links back to playlists list" do
        get "/podcast/playlists/#{playlist.id}"
        expect(response.body).to include(podcast_playlists_path)
      end
    end
  end
end
