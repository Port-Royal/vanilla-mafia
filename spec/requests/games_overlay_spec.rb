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

    context "with the full-canvas layout" do
      let(:document) { response.parsed_body }
      let(:header_slots) { document.css(".overlay-header > div").map { |slot| [ slot["id"], slot.text.strip ] } }
      let(:tile_ids) { document.css(".overlay-tiles > .overlay-tile").map { |tile| tile["id"] } }

      before { get overlay_game_path(game) }

      it "renders the overlay as a full canvas" do
        expect(document.css("#game-overlay.overlay-canvas").size).to eq(1)
      end

      it "renders header slots for the table, the game number and the judge" do
        expect(header_slots.map(&:first)).to eq(%w[overlay-table overlay-game-number overlay-judge])
      end

      it "renders every seat card as a fixed-aspect tile in the bottom row" do
        expect(tile_ids).to eq((1..10).map { |seat| "seat-#{seat}" })
      end
    end

    context "with the header" do
      let(:document) { response.parsed_body }
      let(:header_texts) { %w[overlay-table overlay-game-number overlay-judge].map { |id| document.at_css("##{id}").text.strip } }
      let(:overlay) { document.at_css("#game-overlay") }

      before { get overlay_game_path(header_game) }

      context "when the table number and the judge are set" do
        let_it_be(:header_game) { create(:game, game_number: 3, games_total: 8, competition: competition, table_number: 2, judge: "Кузнецов") }

        it "shows the table, the game number out of the total and the judge" do
          expect(header_texts).to eq([ "Стол 2", "Игра 3/8", "Судья Кузнецов" ])
        end

        it "keeps the game number and the total for live updates" do
          expect(document.at_css("#overlay-game-number").to_h).to include(
            "data-game-overlay-target" => "gameNumber", "data-number" => "3", "data-total" => "8"
          )
        end
      end

      context "when the table number and the judge are blank" do
        let_it_be(:header_game) { create(:game, game_number: 4, competition: competition, table_number: nil, judge: "") }

        it "shows only the game number" do
          expect(header_texts).to eq([ "", "Игра 4", "" ])
        end

        it "keeps an empty total for live updates" do
          expect(document.at_css("#overlay-game-number")["data-total"]).to eq("")
        end
      end

      context "with live update templates" do
        let_it_be(:header_game) { create(:game, game_number: 5, competition: competition) }

        it "exposes the table and judge label templates for the overlay controller" do
          expect(overlay.to_h).to include(
            "data-game-overlay-table-template-value" => "Стол %VALUE%",
            "data-game-overlay-judge-template-value" => "Судья %VALUE%",
            "data-game-overlay-game-template-value" => "Игра %NUMBER%",
            "data-game-overlay-game-of-total-template-value" => "Игра %NUMBER%/%TOTAL%"
          )
        end

        it "marks the table and judge slots as controller targets" do
          expect(%w[overlay-table overlay-judge].map { |id| document.at_css("##{id}")["data-game-overlay-target"] }).to eq(%w[table judge])
        end
      end
    end

    it "displays player names inside their cards" do
      get overlay_game_path(game)

      expect(response.body).to include("Алексей")
      expect(response.body).to include("Борис")
    end

    it "renders a default photo placeholder for players without an attached photo" do
      get overlay_game_path(game)

      expect(response.body).to include(Player::DEFAULT_PHOTO_PATH)
    end

    context "with player tiles" do
      let_it_be(:role_mafia) { create(:role, code: "mafia", name: "Мафия") }
      let_it_be(:role_peace) { create(:role, code: "peace", name: "Мирный") }
      let_it_be(:tile_game) { create(:game, game_number: 7, competition: competition) }

      let_it_be(:tile_participations) do
        [
          [ 1, "sheriff", :alive ],
          [ 2, "don", :killed_by_mafia ],
          [ 3, "mafia", :voted_out ],
          [ 4, "peace", :banned ],
          [ 5, nil, :alive ]
        ].each do |seat, role_code, status|
          create(:game_participation, game: tile_game, player: create(:player, name: "Игрок #{seat}"),
                                      seat: seat, role_code: role_code, status: status)
        end
      end

      let(:document) { response.parsed_body }
      let(:tile) { ->(seat) { document.at_css("#seat-#{seat}") } }
      let(:badge) { ->(seat) { tile.(seat).at_css(".overlay-role-badge") } }
      let(:status_icon) { ->(seat) { tile.(seat).at_css(".overlay-status-icon svg") } }

      let(:overlay_params) { {} }

      before { get overlay_game_path(tile_game, **overlay_params) }

      { 1 => "Ш", 2 => "Д", 3 => "М" }.each do |seat, letter|
        it "shows the #{letter} badge on seat #{seat}" do
          expect(badge.(seat).text.strip).to eq(letter)
        end
      end

      it "shows no badge for a civilian" do
        expect(badge.(4).text.strip).to eq("")
      end

      it "shows no badge for a player without a role" do
        expect(badge.(5).text.strip).to eq("")
      end

      it "renders no role icons" do
        expect(document.css(".overlay-tile img[src*='roles/']")).to be_empty
      end

      { 2 => "killed_by_mafia", 3 => "voted_out", 4 => "banned" }.each do |seat, status|
        context "when the player is #{status}" do
          it "shows the #{status} icon" do
            expect(status_icon.(seat)["data-status"]).to eq(status)
          end

          it "dims the tile" do
            expect(tile.(seat)["class"]).to include("overlay-tile--eliminated")
          end
        end
      end

      context "when the player is alive" do
        it "shows no status icon" do
          expect(status_icon.(1)).to be_nil
        end

        it "does not dim the tile" do
          expect(tile.(1)["class"]).not_to include("overlay-tile--eliminated")
        end
      end

      it "renders no status pill" do
        expect(document.text).not_to include(I18n.t("games.overlay.status.alive"))
      end

      it "shows the seat number and the nickname in the bottom row" do
        expect(%w[.overlay-seat .overlay-name].map { |cell| tile.(1).at_css(".overlay-bottom #{cell}").text.strip }).to eq([ "1", "Игрок 1" ])
      end

      it "fills the tile body with the photo" do
        expect(tile.(1).at_css(".overlay-photo img")["class"]).to include("object-cover")
      end

      context "with an empty seat" do
        it "shows the default photo, the seat number and no name" do
          expect([
            tile.(6).at_css(".overlay-photo img")["src"],
            tile.(6).at_css(".overlay-seat").text.strip,
            tile.(6).at_css(".overlay-name").text.strip,
            badge.(6).text.strip,
            status_icon.(6)
          ]).to eq([ Player::DEFAULT_PHOTO_PATH, "6", "", "", nil ])
        end

        it "does not dim the tile" do
          expect(tile.(6)["class"]).not_to include("overlay-tile--eliminated")
        end
      end

      it "exposes the status icon templates for live updates" do
        expect(document.css("template[data-game-overlay-target='statusIconTemplate']").map { |t| t["data-status"] })
          .to eq(%w[killed_by_mafia voted_out banned])
      end

      it "exposes the role badge letters and the default photo for live updates" do
        expect(document.at_css("#game-overlay").to_h).to include(
          "data-game-overlay-role-badges-value" => { sheriff: "Ш", don: "Д", mafia: "М" }.to_json,
          "data-game-overlay-default-photo-value" => Player::DEFAULT_PHOTO_PATH
        )
      end

      context "when hide_roles is set" do
        let(:overlay_params) { { hide_roles: "1" } }

        it "renders no role badges" do
          expect(document.css(".overlay-role-badge")).to be_empty
        end
      end

      context "with the best move strip" do
        let(:strip_cells) do
          ->(seat) { tile.(seat).css(".overlay-best-move .overlay-best-move-cell").map { |cell| [ cell.text.strip, cell["data-colour"] ] } }
        end

        before do
          owner_participation.update!(best_move_seats: best_move_seats)
          get overlay_game_path(tile_game, **overlay_params)
        end

        let(:owner_participation) { tile_game.game_participations.find_by(seat: 4) }

        context "when every named seat is mafia" do
          let(:best_move_seats) { [ 2, 3 ] }

          it "shows black cells" do
            expect(strip_cells.(4)).to eq([ %w[2 black], %w[3 black] ])
          end
        end

        context "when every named seat is a civilian" do
          let(:best_move_seats) { [ 1, 5 ] }

          it "shows red cells, a role-less seat staying neutral" do
            expect(strip_cells.(4)).to eq([ %w[1 red], %w[5 neutral] ])
          end
        end

        context "when the guess is mixed" do
          let(:best_move_seats) { [ 2, 1, 8 ] }

          it "colours each cell by the named player's role" do
            expect(strip_cells.(4)).to eq([ %w[2 black], %w[1 red], %w[8 neutral] ])
          end
        end

        context "when no seats are named" do
          let(:best_move_seats) { nil }

          it "renders an empty strip" do
            expect(tile.(4).at_css(".overlay-best-move").children).to be_empty
          end
        end

        context "when roles are hidden" do
          let(:best_move_seats) { [ 2, 1 ] }
          let(:overlay_params) { { hide_roles: "1" } }

          it "shows the seats without role colours" do
            expect(strip_cells.(4)).to eq([ %w[2 neutral], %w[1 neutral] ])
          end

          it "exposes no roles for live updates" do
            expect(document.at_css("#game-overlay").to_h).to include(
              "data-game-overlay-seat-roles-value" => "{}",
              "data-game-overlay-best-move-colours-value" => "{}"
            )
          end
        end

        context "when roles are shown" do
          let(:best_move_seats) { [ 2 ] }

          it "exposes seat roles and role colours for live updates" do
            expect(document.at_css("#game-overlay").to_h).to include(
              "data-game-overlay-seat-roles-value" => { "1" => "sheriff", "2" => "don", "3" => "mafia", "4" => "peace" }.to_json,
              "data-game-overlay-best-move-colours-value" => GamesHelper::OVERLAY_BEST_MOVE_COLOURS.to_json
            )
          end
        end
      end

      context "when hide_status is set" do
        let(:overlay_params) { { hide_status: "1" } }

        it "renders no status icons" do
          expect(document.css(".overlay-status-icon")).to be_empty
        end
      end

      context "when hide_seats is set" do
        let(:overlay_params) { { hide_seats: "1" } }

        it "renders no seat cells" do
          expect(document.css(".overlay-seat")).to be_empty
        end
      end
    end

    it "includes ActionCable subscription data for the game" do
      get overlay_game_path(game)

      expect(response.body).to include(game.id.to_s)
    end

    context "with an unseated legacy participation" do
      let_it_be(:legacy_game) { create(:game, game_number: 9, competition: competition) }
      let_it_be(:seated) { create(:game_participation, game: legacy_game, player: player_one, seat: 1, role_code: "sheriff") }
      let_it_be(:unseated) { create(:game_participation, game: legacy_game, player: player_two, seat: nil, role_code: "don") }

      before { get overlay_game_path(legacy_game) }

      it "renders the overlay" do
        expect(response).to have_http_status(:ok)
      end

      it "keeps the unseated participation out of the seat roles" do
        expect(response.parsed_body.at_css("#game-overlay")["data-game-overlay-seat-roles-value"]).to eq({ "1" => "sheriff" }.to_json)
      end
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
    end
  end
end
