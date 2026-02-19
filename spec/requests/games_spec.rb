require "rails_helper"

RSpec.describe GamesController do
  describe "GET /games/:id" do
    let_it_be(:game) { create(:game, season: 1, series: 1, game_number: 1) }

    context "when game exists" do
      let_it_be(:role) { create(:role, code: "peace", name: "Мирный") }
      let_it_be(:rating) { create(:rating, game: game, role_code: "peace", plus: 2.0, minus: 0.5) }

      before { get game_path(game) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the game full name" do
        expect(response.body).to include(game.full_name)
      end

      it "renders player name" do
        expect(response.body).to include(rating.player.name)
      end

      it "renders role name" do
        expect(response.body).to include("Мирный")
      end
    end

    context "when game does not exist" do
      before { get game_path(id: -1) }

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
