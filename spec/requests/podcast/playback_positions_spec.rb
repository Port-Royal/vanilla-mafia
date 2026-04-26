require "rails_helper"

RSpec.describe "Podcast::PlaybackPositions" do
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:episode) { create(:episode, status: "published", published_at: Time.current) }
  let_it_be(:draft_episode) { create(:episode, status: "draft") }
  let_it_be(:scheduled_future_episode) do
    create(:episode, status: "published", published_at: 1.day.from_now)
  end
  let_it_be(:published_without_timestamp_episode) do
    create(:episode, status: "published", published_at: nil)
  end

  describe "PATCH /podcast/episodes/:episode_id/position" do
    let(:params) { { position_seconds: 120 } }

    context "when not signed in" do
      it "redirects to sign in" do
        patch "/podcast/episodes/#{episode.id}/position", params: params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      before { sign_in user }

      it "returns not found" do
        patch "/podcast/episodes/#{episode.id}/position", params: params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as subscriber" do
      before { sign_in subscriber }

      it "creates a new playback position" do
        expect {
          patch "/podcast/episodes/#{episode.id}/position", params: params
        }.to change(PlaybackPosition, :count).by(1)
      end

      it "returns success" do
        patch "/podcast/episodes/#{episode.id}/position", params: params
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON with saved position" do
        patch "/podcast/episodes/#{episode.id}/position", params: params
        expect(response.parsed_body).to eq("position_seconds" => 120, "playback_speed" => 1.0)
      end

      it "updates an existing playback position" do
        create(:playback_position, user: subscriber, episode: episode, position_seconds: 60)

        expect {
          patch "/podcast/episodes/#{episode.id}/position", params: params
        }.not_to change(PlaybackPosition, :count)

        expect(PlaybackPosition.find_by(user: subscriber, episode: episode).position_seconds).to eq(120)
      end

      it "saves playback speed" do
        patch "/podcast/episodes/#{episode.id}/position", params: { position_seconds: 100, playback_speed: 1.5 }
        expect(PlaybackPosition.find_by(user: subscriber, episode: episode).playback_speed).to eq(1.5)
      end

      it "returns saved playback speed in JSON" do
        patch "/podcast/episodes/#{episode.id}/position", params: { position_seconds: 100, playback_speed: 1.75 }
        expect(response.parsed_body["playback_speed"]).to eq(1.75)
      end

      it "defaults playback speed to 1.0 when not provided" do
        patch "/podcast/episodes/#{episode.id}/position", params: params
        expect(PlaybackPosition.find_by(user: subscriber, episode: episode).playback_speed).to eq(1.0)
      end

      it "rejects negative position" do
        patch "/podcast/episodes/#{episode.id}/position", params: { position_seconds: -1 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects non-integer position" do
        patch "/podcast/episodes/#{episode.id}/position", params: { position_seconds: "abc" }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects invalid playback speed" do
        patch "/podcast/episodes/#{episode.id}/position", params: { position_seconds: 100, playback_speed: 3.0 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns not found for non-existent episode" do
        patch "/podcast/episodes/0/position", params: params
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for draft episode" do
        patch "/podcast/episodes/#{draft_episode.id}/position", params: params
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for episode scheduled in the future" do
        patch "/podcast/episodes/#{scheduled_future_episode.id}/position", params: params
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for published episode with nil published_at" do
        patch "/podcast/episodes/#{published_without_timestamp_episode.id}/position", params: params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as admin" do
      before { sign_in admin }

      it "returns success" do
        patch "/podcast/episodes/#{episode.id}/position", params: params
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
