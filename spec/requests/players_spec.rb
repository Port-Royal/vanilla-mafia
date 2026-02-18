require "rails_helper"

RSpec.describe PlayersController do
  describe "GET /players/:id" do
    context "when player exists" do
      let!(:player) { create(:player, name: "Алексей") }
      let!(:game) { create(:game, season: 5, series: 1, game_number: 1) }
      let!(:rating) { create(:rating, game: game, player: player) }
      let!(:award) { create(:award, title: "Лучший игрок") }
      let!(:player_award) { create(:player_award, player: player, award: award, season: 5) }

      before { get player_path(player) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the player name" do
        expect(response.body).to include("Алексей")
      end

      it "renders season heading" do
        expect(response.body).to include("Сезон 5")
      end

      it "renders game link" do
        expect(response.body).to include(game_path(game))
      end

      it "renders award title" do
        expect(response.body).to include("Лучший игрок")
      end
    end

    context "when player does not exist" do
      before { get player_path(id: -1) }

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
