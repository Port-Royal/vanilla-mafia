require "rails_helper"

RSpec.describe "Navigation" do
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }

  describe "podcast link" do
    context "when signed in as subscriber" do
      before { sign_in subscriber }

      it "displays the podcast link" do
        get "/news"
        expect(response.body).to include(podcast_episodes_path)
      end
    end

    context "when signed in as admin" do
      before { sign_in admin }

      it "displays the podcast link" do
        get "/news"
        expect(response.body).to include(podcast_episodes_path)
      end
    end

    context "when signed in as regular user" do
      before { sign_in user }

      it "does not display the podcast link" do
        get "/news"
        expect(response.body).not_to include(podcast_episodes_path)
      end
    end

    context "when not signed in" do
      it "does not display the podcast link" do
        get "/news"
        expect(response.body).not_to include(podcast_episodes_path)
      end
    end
  end
end
