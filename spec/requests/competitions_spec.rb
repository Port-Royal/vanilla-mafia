require "rails_helper"

RSpec.describe CompetitionsController do
  describe "GET /competitions/:slug" do
    context "when competition is a parent with children" do
      let_it_be(:parent) { create(:competition, :season, name: "Season 5", slug: "season-5") }
      let_it_be(:child1) { create(:competition, :series, name: "Series 1", parent: parent, position: 1) }
      let_it_be(:child2) { create(:competition, :series, name: "Series 2", parent: parent, position: 2) }
      let_it_be(:game1) { create(:game, competition: child1, game_number: 1) }
      let_it_be(:player) { create(:player, name: "Алексей") }
      let_it_be(:participation) { create(:game_participation, game: game1, player: player, plus: 3.0, minus: 0.5, win: true) }

      before { get competition_path(slug: parent.slug) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the competition name" do
        expect(response.body).to include("Season 5")
      end

      it "assigns child competitions" do
        expect(response.body).to include("Series 1")
        expect(response.body).to include("Series 2")
      end
    end

    context "when competition is a leaf" do
      let_it_be(:competition) { create(:competition, :series, name: "Series 1", slug: "series-1") }
      let_it_be(:game) { create(:game, competition: competition, game_number: 1) }
      let_it_be(:player) { create(:player, name: "Борис") }
      let_it_be(:participation) { create(:game_participation, game: game, player: player, plus: 2.0, minus: 0.5) }

      before { get competition_path(slug: competition.slug) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when competition has no games" do
      let_it_be(:competition) { create(:competition, name: "Empty", slug: "empty") }

      before { get competition_path(slug: competition.slug) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when competition does not exist" do
      it "returns not found" do
        get competition_path(slug: "nonexistent")
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
