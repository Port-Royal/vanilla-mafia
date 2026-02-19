require "rails_helper"

RSpec.describe SeasonsController do
  describe "GET /seasons/:number" do
    context "when season has games and players" do
      let!(:game1) { create(:game, season: 5, series: 1, game_number: 1) }
      let!(:game2) { create(:game, season: 5, series: 2, game_number: 1) }
      let!(:player1) { create(:player, name: "Алексей") }
      let!(:player2) { create(:player, name: "Борис") }
      let!(:rating1) { create(:rating, game: game1, player: player1, plus: 3.0, minus: 0.5, win: true) }
      let!(:rating2) { create(:rating, game: game1, player: player2, plus: 1.0, minus: 1.5, win: false) }
      let!(:rating3) { create(:rating, game: game2, player: player2, plus: 4.0, minus: 0.0, win: true) }

      before { get season_path(number: 5) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders series headings" do
        expect(response.body).to include("Серия 1")
        expect(response.body).to include("Серия 2")
      end

      it "renders game links" do
        expect(response.body).to include(game_path(game1))
        expect(response.body).to include(game_path(game2))
      end

      it "renders player rankings" do
        expect(response.body).to include("Алексей")
        expect(response.body).to include("Борис")
      end

      it "renders ranking table headers" do
        expect(response.body).to include("Место")
        expect(response.body).to include("Рейтинг")
        expect(response.body).to include("Игры")
        expect(response.body).to include("Процент побед")
      end
    end

    context "when season has no games" do
      before { get season_path(number: 99) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
