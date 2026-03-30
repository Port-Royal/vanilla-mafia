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

      it "displays personal feed URL" do
        get "/podcast/episodes"
        token = subscriber.podcast_feed_token
        expect(response.body).to include(podcast_feed_url(format: :rss, token: token.token))
      end

      it "creates a feed token if user does not have one" do
        new_user = create(:user, :subscriber)
        sign_in new_user
        expect { get "/podcast/episodes" }.to change(PodcastFeedToken, :count).by(1)
      end

      it "reuses existing feed token" do
        create(:podcast_feed_token, user: subscriber)
        expect { get "/podcast/episodes" }.not_to change(PodcastFeedToken, :count)
      end

      it "includes copy button with clipboard controller" do
        get "/podcast/episodes"
        expect(response.body).to include('data-controller="clipboard"')
      end

      it "includes link to podcast feed help page" do
        get "/podcast/episodes"
        expect(response.body).to include(help_path(slug: "podcast-feed"))
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

      it "shows placeholder when no audio attached" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include("audio-player-placeholder")
      end

      it "links back to episodes list" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include(podcast_episodes_path)
      end

      context "when episode has audio" do
        let(:episode_with_audio) do
          episode = create(:episode, title: "Audio Episode", status: "published", published_at: Time.current)
          episode.audio.attach(
            io: StringIO.new("fake-audio"),
            filename: "episode.mp3",
            content_type: "audio/mpeg"
          )
          episode
        end

        it "renders the audio player with Stimulus controller" do
          get "/podcast/episodes/#{episode_with_audio.id}"
          expect(response.body).to include('data-controller="audio-player"')
        end

        it "includes saved position value" do
          create(:playback_position, user: subscriber, episode: episode_with_audio, position_seconds: 90)
          get "/podcast/episodes/#{episode_with_audio.id}"
          expect(response.body).to include('data-audio-player-saved-position-value="90"')
        end

        it "defaults saved position to zero" do
          get "/podcast/episodes/#{episode_with_audio.id}"
          expect(response.body).to include('data-audio-player-saved-position-value="0"')
        end

        it "includes speed control button" do
          get "/podcast/episodes/#{episode_with_audio.id}"
          expect(response.body).to include('data-audio-player-target="speedButton"')
        end

        it "renders progress bar with slider role" do
          get "/podcast/episodes/#{episode_with_audio.id}"
          expect(response.body).to include('role="slider"')
        end

        it "includes episode title value for media session" do
          get "/podcast/episodes/#{episode_with_audio.id}"
          expect(response.body).to include('data-audio-player-episode-title-value="Audio Episode"')
        end

        it "includes position URL for auto-save" do
          get "/podcast/episodes/#{episode_with_audio.id}"
          expect(response.body).to include("data-audio-player-position-url-value=\"#{podcast_episode_position_path(episode_with_audio)}\"")
        end

        it "does not show placeholder" do
          get "/podcast/episodes/#{episode_with_audio.id}"
          expect(response.body).not_to include("audio-player-placeholder")
        end
      end

      it "defaults saved position to zero on placeholder when no audio" do
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include('data-saved-position="0"')
      end

      it "includes saved position on placeholder when no audio" do
        create(:playback_position, user: subscriber, episode: published_episode, position_seconds: 90)
        get "/podcast/episodes/#{published_episode.id}"
        expect(response.body).to include('data-saved-position="90"')
      end
    end
  end
end
