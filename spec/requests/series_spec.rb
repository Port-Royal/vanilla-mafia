require "rails_helper"

RSpec.describe SeriesController do
  describe "GET /seasons/:season_number/series/:number" do
    context "when series has games" do
      let!(:game1) { create(:game, season: 5, series: 1, game_number: 1) }
      let!(:game2) { create(:game, season: 5, series: 1, game_number: 2) }
      let!(:player1) { create(:player, name: "Алексей") }
      let!(:player2) { create(:player, name: "Борис") }
      let!(:rating1) { create(:rating, game: game1, player: player1, plus: 3.0, minus: 0.5) }
      let!(:rating2) { create(:rating, game: game1, player: player2, plus: 1.0, minus: 1.5) }
      let!(:rating3) { create(:rating, game: game2, player: player1, plus: 2.0, minus: 1.0) }
      let!(:rating4) { create(:rating, game: game2, player: player2, plus: 5.0, minus: 0.0) }

      before { get season_series_path(season_number: 5, number: 1) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders player names" do
        expect(response.body).to include("Алексей")
        expect(response.body).to include("Борис")
      end

      it "renders game columns" do
        expect(response.body).to include("Игра 1")
        expect(response.body).to include("Игра 2")
      end

      it "renders total column" do
        expect(response.body).to include("Итого")
      end

      it "sorts players by total descending" do
        expect(response.body).to match(/Борис.*Алексей/m)
      end
    end

    context "when series has no games" do
      before { get season_series_path(season_number: 99, number: 99) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
