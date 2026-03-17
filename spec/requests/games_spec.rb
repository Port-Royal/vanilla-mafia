require "rails_helper"

RSpec.describe GamesController do
  describe "GET /games/:id" do
    let_it_be(:season) { create(:competition, :season, name: "Сезон 1") }
    let_it_be(:series) { create(:competition, :series, name: "Серия 1", parent: season) }
    let_it_be(:game) { create(:game, competition: series, game_number: 1) }

    context "when game exists" do
      let_it_be(:role) { create(:role, code: "peace", name: "Мирный") }
      let_it_be(:participation) { create(:game_participation, game: game, role_code: "peace", plus: 2.0, minus: 0.5, seat: 3) }

      before { get game_path(game) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders breadcrumb with link to root competition" do
        assert_select "nav a[href=?]", competition_path(slug: season.slug), text: season.name
      end

      it "renders breadcrumb with link to parent competition" do
        assert_select "nav a[href=?]", competition_path(slug: series.slug), text: series.name
      end

      it "renders breadcrumb with game name as text" do
        assert_select "nav span", text: /#{I18n.t('common.game')} #{game.game_number}/
      end

      it "renders player name as link to profile" do
        assert_select "td a[href=?]", player_path(participation.player), text: participation.player.name
      end

      it "renders role icon" do
        assert_select "td img[src*='roles/peace'][alt='Мирный']"
      end

      it "renders seat number in table cell" do
        assert_select "tbody td", text: "3"
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
