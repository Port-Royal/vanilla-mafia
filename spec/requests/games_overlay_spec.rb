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

    it "renders a card per seat (10 cards)" do
      get overlay_game_path(game)

      (1..10).each do |seat|
        expect(response.body).to include(%(id="seat-#{seat}"))
      end
    end

    it "displays player names inside their cards" do
      get overlay_game_path(game)

      expect(response.body).to include("Алексей")
      expect(response.body).to include("Борис")
    end

    it "displays player roles" do
      get overlay_game_path(game)

      expect(response.body).to include("sheriff")
      expect(response.body).to include("don")
    end

    it "renders a default photo placeholder for players without an attached photo" do
      get overlay_game_path(game)

      expect(response.body).to include(Player::DEFAULT_PHOTO_PATH)
    end

    it "renders a status pill with the default :alive status for every taken seat" do
      get overlay_game_path(game)

      expect(response.body.scan(I18n.t("games.overlay.status.alive")).size).to be >= 2
    end

    it "includes ActionCable subscription data for the game" do
      get overlay_game_path(game)

      expect(response.body).to include(game.id.to_s)
    end

    it "returns not found for non-existent game" do
      get overlay_game_path(slug: "nonexistent-slug")

      expect(response).to have_http_status(:not_found)
    end

    context "with URL parameter customization" do
      it "applies custom font size" do
        get overlay_game_path(game, font_size: "24")

        expect(response.body).to include('font-size: 24px')
      end

      it "ignores invalid font size" do
        get overlay_game_path(game, font_size: "abc")

        expect(response.body).not_to include("font-size:")
      end

      it "clamps font size to allowed range" do
        get overlay_game_path(game, font_size: "200")

        expect(response.body).to include("font-size: 72px")
      end

      it "applies custom text color" do
        get overlay_game_path(game, color: "ff0000")

        expect(response.body).to include("color: #ff0000")
      end

      it "ignores invalid color" do
        get overlay_game_path(game, color: "not-a-color")

        expect(response.body).not_to include("color:")
      end

      it "ignores color with invalid length" do
        get overlay_game_path(game, color: "ff00f")

        expect(response.body).not_to include("color:")
      end

      it "accepts 3-digit hex color" do
        get overlay_game_path(game, color: "f00")

        expect(response.body).to include("color: #f00")
      end

      it "handles array parameter for font_size gracefully" do
        get overlay_game_path(game, font_size: [ "24" ])

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("font-size:")
      end

      it "handles array parameter for color gracefully" do
        get overlay_game_path(game, color: [ "ff0000" ])

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("color:")
      end

      it "hides role display when hide_roles param is set" do
        get overlay_game_path(game, hide_roles: "1")

        expect(response.body).not_to include("sheriff")
      end

      it "hides seat numbers when hide_seats param is set" do
        get overlay_game_path(game, hide_seats: "1")

        expect(response.body).not_to include("#1")
      end

      it "hides status pill when hide_status param is set" do
        get overlay_game_path(game, hide_status: "1")

        expect(response.body).not_to include(I18n.t("games.overlay.status.alive"))
      end
    end
  end
end
