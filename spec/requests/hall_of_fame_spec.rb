require "rails_helper"

RSpec.describe HallOfFameController do
  describe "GET /hall" do
    context "when awards exist" do
      let!(:player) { create(:player, name: "Алексей") }
      let!(:organizer) { create(:player, name: "Ведущий") }
      let!(:award) { create(:award, title: "Лучший игрок", staff: false) }
      let!(:staff_award) { create(:award, title: "Лучший ведущий", staff: true) }
      let!(:player_award) { create(:player_award, player: player, award: award, season: 5) }
      let!(:staff_player_award) { create(:player_award, player: organizer, award: staff_award, season: 5) }

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
