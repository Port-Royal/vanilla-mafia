require "rails_helper"

RSpec.describe "Table overlays" do
  let_it_be(:role_don) { create(:role, code: "don", name: "Дон") }
  let_it_be(:today) { Date.current }

  let(:overlay) { response.parsed_body.at_css("#table-overlay") }
  let(:game_canvas) { response.parsed_body.at_css("#game-overlay") }

  describe "GET /overlay" do
    context "with no games" do
      before { get overlay_path }

      it "renders an empty canvas" do
        expect([ response.status, game_canvas ]).to eq([ 200, nil ])
      end

      it "listens to table 1" do
        expect(overlay["data-table-overlay-table-value"]).to eq("1")
      end

      it "has no current game" do
        expect(overlay["data-table-overlay-game-id-value"]).to eq("")
      end

      it "uses the overlay layout" do
        expect(response.body).not_to include("Vanilla Mafia")
      end
    end

    context "with a game in progress today without a table number" do
      let_it_be(:game) { create(:game, table_number: nil, played_on: today, judge: "Судья Стола") }

      before { get overlay_path }

      it "shows that game" do
        expect(game_canvas["data-game-overlay-game-id-value"]).to eq(game.id.to_s)
      end

      it "tells the table listener which game is on" do
        expect(overlay["data-table-overlay-game-id-value"]).to eq(game.id.to_s)
      end

      it "renders the game header" do
        expect(response.body).to include("Судья Стола")
      end
    end

    context "with a game set to hide game info" do
      let_it_be(:game) { create(:game, table_number: 1, played_on: today, hide_game_info: true) }

      before { get overlay_path }

      it "keeps the game's display settings" do
        expect(game_canvas["class"]).to include("overlay-canvas--hide-game-info")
      end
    end

    context "with hidden roles" do
      let_it_be(:game) { create(:game, table_number: 1, played_on: today, hide_roles: true) }
      let_it_be(:don) { create(:game_participation, game:, seat: 1, role_code: "don") }

      before { get overlay_path }

      it "keeps the roles hidden" do
        expect(response.parsed_body.at_css("[data-game-overlay-target='roleBadge'][data-seat='1']")["data-role"]).to be_nil
      end
    end
  end

  describe "GET /overlay/tables/:number" do
    let_it_be(:first) { create(:game, table_number: 1, played_on: today) }
    let_it_be(:second) { create(:game, table_number: 2, played_on: today) }

    context "with table 2" do
      before { get table_overlay_path(number: 2) }

      it "shows the game at table 2" do
        expect(game_canvas["data-game-overlay-game-id-value"]).to eq(second.id.to_s)
      end

      it "listens to table 2" do
        expect(overlay["data-table-overlay-table-value"]).to eq("2")
      end
    end

    context "with table 1" do
      before { get table_overlay_path(number: 1) }

      it "shows the game at table 1" do
        expect(game_canvas["data-game-overlay-game-id-value"]).to eq(first.id.to_s)
      end
    end

    context "with table 1 and a later game without a table number" do
      let_it_be(:no_table) { create(:game, table_number: nil, played_on: today, created_at: 1.minute.from_now) }

      before { get table_overlay_path(number: 1) }

      it "shows the game without a table number" do
        expect(game_canvas["data-game-overlay-game-id-value"]).to eq(no_table.id.to_s)
      end
    end

    context "with a table that has no game" do
      before { get table_overlay_path(number: 7) }

      it "renders an empty canvas" do
        expect([ response.status, game_canvas ]).to eq([ 200, nil ])
      end
    end

    context "with a table number that is not a positive number" do
      it "does not route zero" do
        get "/overlay/tables/0"
        expect(response).to have_http_status(:not_found)
      end

      it "does not route words" do
        get "/overlay/tables/abc"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
