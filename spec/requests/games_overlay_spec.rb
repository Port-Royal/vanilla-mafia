require "rails_helper"

RSpec.describe "Games#overlay" do
  let_it_be(:competition) { create(:competition, :series) }
  let_it_be(:role_sheriff) { create(:role, code: "sheriff", name: "Шериф") }
  let_it_be(:role_don) { create(:role, code: "don", name: "Дон") }
  let_it_be(:player_one) { create(:player, name: "Алексей") }
  let_it_be(:player_two) { create(:player, name: "Борис") }

  let_it_be(:game) do
    create(:game, game_number: 1, competition: competition, judge: "Судья")
  end

  let_it_be(:participation_one) do
    create(:game_participation, game: game, player: player_one, seat: 1, role_code: "sheriff")
  end

  let_it_be(:participation_two) do
    create(:game_participation, game: game, player: player_two, seat: 2, role_code: "don")
  end

  describe "GET /games/:id/overlay" do
    it "renders the overlay page" do
      get overlay_game_path(game)

      expect(response).to have_http_status(:ok)
    end

    it "uses the overlay layout" do
      get overlay_game_path(game)

      expect(response.body).not_to include("Vanilla Mafia")
      expect(response.body).to include("game-overlay")
    end

    it "displays player names with seat numbers" do
      get overlay_game_path(game)

      expect(response.body).to include("Алексей")
      expect(response.body).to include("Борис")
    end

    it "displays player roles" do
      get overlay_game_path(game)

      expect(response.body).to include("sheriff")
      expect(response.body).to include("don")
    end

    it "includes ActionCable subscription data for the game" do
      get overlay_game_path(game)

      expect(response.body).to include(game.id.to_s)
    end

    it "returns not found for non-existent game" do
      get overlay_game_path(id: -1)

      expect(response).to have_http_status(:not_found)
    end
  end
end
