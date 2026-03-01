require "rails_helper"

RSpec.describe HallOfFameController do
  describe "GET /hall" do
    context "when awards exist" do
      let_it_be(:player) { create(:player, name: "Алексей") }
      let_it_be(:organizer) { create(:player, name: "Ведущий") }
      let_it_be(:award) { create(:award, title: "Лучший игрок", staff: false) }
      let_it_be(:staff_award) { create(:award, title: "Лучший ведущий", staff: true) }
      let_it_be(:player_award) { create(:player_award, player: player, award: award, season: 5) }
      let_it_be(:staff_player_award) { create(:player_award, player: organizer, award: staff_award, season: 5) }

      before { get hall_path }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the hall of fame title" do
        expect(response.body).to include("Зал Славы")
      end

      it "renders player awards" do
        expect(response.body).to include("Алексей")
        expect(response.body).to include("Лучший игрок")
      end

      it "renders default photo for players without uploaded pictures" do
        expect(response.body).to include(Player::DEFAULT_PHOTO_PATH)
      end

      it "renders staff section" do
        expect(response.body).to include("Организаторы")
        expect(response.body).to include("Ведущий")
        expect(response.body).to include("Лучший ведущий")
      end
    end

    context "when no awards exist" do
      before { get hall_path }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders coming soon message" do
        expect(response.body).to include("Скоро! Следите за обновлениями")
      end

      it "does not render organizers heading" do
        expect(response.body).not_to include("Организаторы")
      end
    end
  end
end
