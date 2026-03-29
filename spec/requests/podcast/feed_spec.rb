require "rails_helper"

RSpec.describe "Podcast::Feed" do
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:token) { create(:podcast_feed_token, user: subscriber) }
  let_it_be(:published_episode) do
    create(:episode, title: "First Episode", description: "A great episode",
           status: "published", published_at: 1.day.ago)
  end
  let_it_be(:another_episode) do
    create(:episode, title: "Second Episode", description: "Another episode",
           status: "published", published_at: Time.current)
  end
  let_it_be(:draft_episode) { create(:episode, status: "draft") }

  describe "GET /podcast/feed.rss" do
    context "when token is missing" do
      it "returns unauthorized" do
        get "/podcast/feed.rss"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when token is invalid" do
      it "returns unauthorized" do
        get "/podcast/feed.rss?token=invalid"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when token is revoked" do
      let(:revoked_token) { create(:podcast_feed_token, revoked_at: 1.day.ago) }

      it "returns unauthorized" do
        get "/podcast/feed.rss?token=#{revoked_token.token}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when token is valid" do
      it "returns success" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response).to have_http_status(:ok)
      end

      it "returns RSS content type" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response.content_type).to include("application/rss+xml")
      end

      it "includes podcast title" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response.body).to include("<title>Vanilla Mafia</title>")
      end

      it "includes podcast description" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response.body).to include("<description>")
      end

      it "includes iTunes namespace" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response.body).to include("xmlns:itunes")
      end

      it "includes published episodes" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response.body).to include("First Episode")
        expect(response.body).to include("Second Episode")
      end

      it "excludes draft episodes" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response.body).not_to include(draft_episode.title)
      end

      it "orders episodes by published_at descending" do
        get "/podcast/feed.rss?token=#{token.token}"
        first_pos = response.body.index("Second Episode")
        second_pos = response.body.index("First Episode")
        expect(first_pos).to be < second_pos
      end

      it "includes episode pub dates" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response.body).to include("<pubDate>")
      end

      it "includes episode descriptions" do
        get "/podcast/feed.rss?token=#{token.token}"
        expect(response.body).to include("A great episode")
      end
    end
  end
end
