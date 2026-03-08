require "rails_helper"

RSpec.describe GamesController do
  describe "GET /games/:id" do
    let_it_be(:game) { create(:game, season: 1, series: 1, game_number: 1) }

    context "when game exists" do
      let_it_be(:role) { create(:role, code: "peace", name: "Мирный") }
      let_it_be(:participation) { create(:game_participation, game: game, role_code: "peace", plus: 2.0, minus: 0.5, seat: 3) }

      before { get game_path(game) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the game full name" do
        expect(response.body).to include(game.full_name)
      end

      it "renders player name as link to profile" do
        expect(response.body).to include(player_path(participation.player))
        expect(response.body).to include(participation.player.name)
      end

      it "renders role icon" do
        expect(response.body).to include("roles/peace")
        expect(response.body).to include("<img")
      end

      it "renders seat number" do
        expect(response.body).to include("3")
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
