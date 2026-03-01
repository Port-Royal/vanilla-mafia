require "rails_helper"

RSpec.describe SeasonsController do
  describe "GET /seasons/:number" do
    context "when season has games and players" do
      let_it_be(:game1) { create(:game, season: 5, series: 1, game_number: 1) }
      let_it_be(:game2) { create(:game, season: 5, series: 2, game_number: 1) }
      let_it_be(:player1) { create(:player, name: "Алексей") }
      let_it_be(:player2) { create(:player, name: "Борис") }
      let_it_be(:participation1) { create(:game_participation, game: game1, player: player1, plus: 3.0, minus: 0.5, win: true) }
      let_it_be(:participation2) { create(:game_participation, game: game1, player: player2, plus: 1.0, minus: 1.5, win: false) }
      let_it_be(:participation3) { create(:game_participation, game: game2, player: player2, plus: 4.0, minus: 0.0, win: true) }

      before { get season_path(number: 5) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders series headings" do
        expect(response.body).to include("Сезон")
        expect(response.body).to include("Серия")
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

    context "when players exceed one page" do
      let_it_be(:game) { create(:game, season: 7, series: 1, game_number: 1) }
      let_it_be(:players) { create_list(:player, 26) }
      let_it_be(:participations) do
        players.map { |p| create(:game_participation, game: game, player: p, plus: 1.0, minus: 0.0) }
      end

      context "when on the first page" do
        before { get season_path(number: 7) }

        it "returns success" do
          expect(response).to have_http_status(:ok)
        end

        it "renders pagination nav" do
          expect(response.body).to include("page=2")
        end

        it "renders the 25th player" do
          ranked_players = Player.with_stats_for_season(7).ranked.to_a
          expect(response.body).to include(ranked_players[24].name)
        end

        it "does not render the 26th player" do
          ranked_players = Player.with_stats_for_season(7).ranked.to_a
          expect(response.body).not_to include(ranked_players[25].name)
        end
      end

      context "when on the second page" do
        before { get season_path(number: 7), params: { page: 2 } }

        it "returns success" do
          expect(response).to have_http_status(:ok)
        end

        it "renders the remaining player" do
          ranked_players = Player.with_stats_for_season(7).ranked.to_a
          last_player = ranked_players.last
          expect(response.body).to include(last_player.name)
        end

        it "shows the correct rank number" do
          expect(response.body).to include("<td>26</td>")
        end
      end
    end
  end
end
