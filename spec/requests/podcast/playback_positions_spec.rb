require "rails_helper"

RSpec.describe "Podcast::PlaybackPositions" do
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:episode) { create(:episode, status: "published", published_at: Time.current) }

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
        expect(response.parsed_body).to eq("position_seconds" => 120)
      end

      it "updates an existing playback position" do
        create(:playback_position, user: subscriber, episode: episode, position_seconds: 60)

        expect {
          patch "/podcast/episodes/#{episode.id}/position", params: params
        }.not_to change(PlaybackPosition, :count)

        expect(PlaybackPosition.find_by(user: subscriber, episode: episode).position_seconds).to eq(120)
      end

      it "rejects negative position" do
        patch "/podcast/episodes/#{episode.id}/position", params: { position_seconds: -1 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects non-integer position" do
        patch "/podcast/episodes/#{episode.id}/position", params: { position_seconds: "abc" }
        expect(response).to have_http_status(:unprocessable_content)
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
