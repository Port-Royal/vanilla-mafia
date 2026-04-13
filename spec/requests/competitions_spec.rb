require "rails_helper"

RSpec.describe CompetitionsController do
  describe "GET /competitions/:slug" do
    context "when competition is a parent with children" do
      let_it_be(:parent) { create(:competition, :season, name: "Season 5", slug: "season-5") }
      let_it_be(:child1) { create(:competition, :series, name: "Series 1", parent: parent, position: 1) }
      let_it_be(:child2) { create(:competition, :series, name: "Series 2", parent: parent, position: 2) }
      let_it_be(:game1) { create(:game, competition: child1, game_number: 1) }
      let_it_be(:game2) { create(:game, competition: child1, game_number: 2) }
      let_it_be(:game3) { create(:game, competition: child2, game_number: 1) }
      let_it_be(:player1) { create(:player, name: "Алексей") }
      let_it_be(:player2) { create(:player, name: "Борис") }
      let_it_be(:participation1) { create(:game_participation, game: game1, player: player1, plus: 3.0, minus: 0.5, win: true) }
      let_it_be(:participation2) { create(:game_participation, game: game1, player: player2, plus: 1.0, minus: 1.5, win: false) }

      before { get competition_path(slug: parent.slug) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the competition name" do
        expect(response.body).to include("Season 5")
      end

      it "renders child competition names" do
        expect(response.body).to include("Series 1")
        expect(response.body).to include("Series 2")
      end

      it "renders game links" do
        expect(response.body).to include(game_path(game1))
        expect(response.body).to include(game_path(game2))
      end

      it "renders child competition links" do
        expect(response.body).to include(competition_path(slug: child1.slug))
      end

      it "renders player rankings" do
        expect(response.body).to include("Алексей")
        expect(response.body).to include("Борис")
      end

      it "renders ranking table headers" do
        expect(response.body).to include(I18n.t("competitions.show.rank"))
        expect(response.body).to include(I18n.t("competitions.show.rating"))
      end

      it "links player names to profiles" do
        expect(response.body).to include(player_path(player1))
      end

      context "with linked news" do
        let_it_be(:author) { create(:user) }
        let_it_be(:parent_article) { create(:news, :published, author: author, competition: parent, title: "Parent season news") }
        let_it_be(:child_article) { create(:news, :published, author: author, competition: child1, title: "Child series news") }
        let_it_be(:draft_article) { create(:news, author: author, competition: parent, title: "Draft parent news") }

        before { get competition_path(slug: parent.slug) }

        it "shows news linked directly to the parent competition" do
          expect(response.body).to include("Parent season news")
        end

        it "does not show news linked only to child competitions" do
          expect(response.body).not_to include("Child series news")
        end

        it "does not show draft news" do
          expect(response.body).not_to include("Draft parent news")
        end
      end
    end

    context "when competition is a leaf" do
      let_it_be(:competition) { create(:competition, :series, name: "Series 1", slug: "series-1") }
      let_it_be(:game1) { create(:game, competition: competition, game_number: 1) }
      let_it_be(:game2) { create(:game, competition: competition, game_number: 2) }
      let_it_be(:player1) { create(:player, name: "Виктор") }
      let_it_be(:player2) { create(:player, name: "Галина") }
      let_it_be(:p1) { create(:game_participation, game: game1, player: player1, plus: 3.0, minus: 0.5) }
      let_it_be(:p2) { create(:game_participation, game: game1, player: player2, plus: 1.0, minus: 1.5) }
      let_it_be(:p3) { create(:game_participation, game: game2, player: player1, plus: 2.0, minus: 1.0) }
      let_it_be(:p4) { create(:game_participation, game: game2, player: player2, plus: 5.0, minus: 0.0) }

      before { get competition_path(slug: competition.slug) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders player names" do
        expect(response.body).to include("Виктор")
        expect(response.body).to include("Галина")
      end

      it "renders game columns" do
        expect(response.body).to include(I18n.t("common.game") + " 1")
        expect(response.body).to include(I18n.t("common.game") + " 2")
      end

      it "renders total column" do
        expect(response.body).to include(I18n.t("competitions.show.total"))
      end

      it "sorts players by total descending" do
        expect(response.body).to match(/Галина.*Виктор/m)
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
