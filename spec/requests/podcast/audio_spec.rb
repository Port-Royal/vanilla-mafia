require "rails_helper"

RSpec.describe "Podcast::Audio" do
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:token) { create(:podcast_feed_token, user: subscriber) }
  let_it_be(:episode) do
    episode = create(:episode, title: "Audio Episode", status: "published", published_at: Time.current)
    episode.audio.attach(
      io: StringIO.new("fake-audio-data"),
      filename: "episode.mp3",
      content_type: "audio/mpeg"
    )
    episode
  end
  let_it_be(:episode_without_audio) do
    create(:episode, title: "No Audio", status: "published", published_at: Time.current)
  end
  let_it_be(:draft_episode) { create(:episode, status: "draft") }
  let_it_be(:scheduled_future_episode) do
    episode = create(:episode, title: "Future Scheduled", status: "published", published_at: 1.day.from_now)
    episode.audio.attach(io: StringIO.new("a"), filename: "f.mp3", content_type: "audio/mpeg")
    episode
  end
  let_it_be(:published_without_timestamp_episode) do
    episode = create(:episode, title: "No Timestamp", status: "published", published_at: nil)
    episode.audio.attach(io: StringIO.new("a"), filename: "n.mp3", content_type: "audio/mpeg")
    episode
  end

  describe "GET /podcast/episodes/:id/audio" do
    context "when token is missing" do
      it "returns unauthorized" do
        get "/podcast/episodes/#{episode.id}/audio"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when token is invalid" do
      it "returns unauthorized" do
        get "/podcast/episodes/#{episode.id}/audio?token=invalid"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when token is revoked" do
      let(:revoked_token) { create(:podcast_feed_token, revoked_at: 1.day.ago) }

      it "returns unauthorized" do
        get "/podcast/episodes/#{episode.id}/audio?token=#{revoked_token.token}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when token is valid" do
      it "redirects to audio blob" do
        get "/podcast/episodes/#{episode.id}/audio?token=#{token.token}"
        expect(response).to have_http_status(:found)
        expect(response.location).to include("/rails/active_storage")
      end

      it "returns not found for episode without audio" do
        get "/podcast/episodes/#{episode_without_audio.id}/audio?token=#{token.token}"
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for draft episode" do
        get "/podcast/episodes/#{draft_episode.id}/audio?token=#{token.token}"
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for episode scheduled in the future" do
        get "/podcast/episodes/#{scheduled_future_episode.id}/audio?token=#{token.token}"
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for published episode with nil published_at" do
        get "/podcast/episodes/#{published_without_timestamp_episode.id}/audio?token=#{token.token}"
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for non-existent episode" do
        get "/podcast/episodes/0/audio?token=#{token.token}"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
