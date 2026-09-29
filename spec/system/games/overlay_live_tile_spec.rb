require "rails_helper"

# The test cable adapter never reaches the browser, so the specs hand a broadcast payload
# straight to the overlay controller, exactly as GameProtocolChannel would deliver it.
RSpec.describe "Game overlay live tiles" do
  let_it_be(:role_sheriff) { create(:role, code: "sheriff") }
  let_it_be(:role_don) { create(:role, code: "don") }
  let_it_be(:role_peace) { create(:role, code: "peace") }
  let_it_be(:game) { create(:game) }
  let_it_be(:player) { create(:player, name: "Кузнецов") }
  let_it_be(:participation) do
    create(:game_participation, game: game, player: player, seat: 1, role_code: "sheriff", status: :banned)
  end

  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")'
  end
  let(:tile_state) do
    page.evaluate_script(<<~JS)
      [1, 2].map((seat) => {
        const tile = document.getElementById(`seat-${seat}`)
        const icon = tile.querySelector(".overlay-status-icon svg")
        return {
          name: tile.querySelector(".overlay-name").textContent.trim(),
          badge: tile.querySelector(".overlay-role-badge").textContent.trim(),
          icon: icon ? icon.dataset.status : null,
          dimmed: tile.classList.contains("overlay-tile--eliminated"),
          photo: tile.querySelector(".overlay-photo img").getAttribute("src")
        }
      })
    JS
  end
  let(:seat_one) { tile_state.first }
  let(:seat_two) { tile_state.last }

  before do
    visit overlay_game_path(game)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "overlay controller is not connected" unless page.evaluate_script("!!#{controller_js}")
    end
    page.execute_script("arguments[0].forEach((payload) => #{controller_js}.handleUpdate(payload))", payloads)
  end

  context "when the role changes to don" do
    let(:payloads) { [ { scope: "participation", seat: 1, field: "role_code", value: "don" } ] }

    it "shows the don badge" do
      expect(seat_one["badge"]).to eq("Д")
    end
  end

  context "when the role changes to peace" do
    let(:payloads) { [ { scope: "participation", seat: 1, field: "role_code", value: "peace" } ] }

    it "removes the badge" do
      expect(seat_one["badge"]).to eq("")
    end
  end

  context "when the player is voted out" do
    let(:payloads) { [ { scope: "participation", seat: 1, field: "status", value: "voted_out" } ] }

    it "swaps the status icon and keeps the tile dimmed" do
      expect(seat_one.values_at("icon", "dimmed")).to eq([ "voted_out", true ])
    end
  end

  context "when the player is back alive" do
    let(:payloads) { [ { scope: "participation", seat: 1, field: "status", value: "alive" } ] }

    it "removes the status icon and the dimming" do
      expect(seat_one.values_at("icon", "dimmed")).to eq([ nil, false ])
    end
  end

  context "when the player is cleared" do
    let(:payloads) { [ { scope: "participation", seat: 1, field: "player_name", value: "" } ] }

    it "clears the tile" do
      expect(seat_one).to eq(
        "name" => "", "badge" => "", "icon" => nil, "dimmed" => false, "photo" => Player::DEFAULT_PHOTO_PATH
      )
    end
  end

  context "when a player takes an empty seat and is killed" do
    let(:payloads) do
      [
        { scope: "participation", seat: 2, field: "player_name", value: "Петров" },
        { scope: "participation", seat: 2, field: "role_code", value: "sheriff" },
        { scope: "participation", seat: 2, field: "status", value: "killed_by_mafia" }
      ]
    end

    it "fills the tile" do
      expect(seat_two.values_at("name", "badge", "icon", "dimmed")).to eq([ "Петров", "Ш", "killed_by_mafia", true ])
    end

    it "leaves the other tiles untouched" do
      expect(seat_one.values_at("name", "badge", "icon", "dimmed")).to eq([ "Кузнецов", "Ш", "banned", true ])
    end
  end
end
