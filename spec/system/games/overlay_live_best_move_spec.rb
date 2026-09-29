require "rails_helper"

# The test cable adapter never reaches the browser, so the specs hand a broadcast payload
# straight to the overlay controller, exactly as GameProtocolChannel would deliver it.
RSpec.describe "Game overlay live best move strip" do
  let_it_be(:roles) { %w[sheriff don mafia peace].map { |code| create(:role, code: code) } }
  let_it_be(:game) { create(:game) }
  let_it_be(:participations) do
    { 1 => "peace", 2 => "don", 3 => "sheriff", 4 => "peace" }.map do |seat, role_code|
      create(:game_participation, game: game, player: create(:player, name: "Игрок #{seat}"), seat: seat, role_code: role_code,
                                  best_move_seats: seat == 1 ? [ 2, 3 ] : nil)
    end
  end

  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")'
  end
  let(:strip) do
    ->(seat) do
      page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll("#seat-#{seat} .overlay-best-move .overlay-best-move-cell"))
          .map((cell) => [cell.textContent.trim(), cell.dataset.colour])
      JS
    end
  end
  before do
    visit overlay_game_path(game)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "overlay controller is not connected" unless page.evaluate_script("!!#{controller_js}")
    end
    page.execute_script("arguments[0].forEach((payload) => #{controller_js}.handleUpdate(payload))", payloads)
  end

  context "when the best move seats change" do
    let(:payloads) { [ { scope: "participation", seat: 1, field: "best_move_seats", value: [ "4", "2", "9" ] } ] }

    it "rebuilds the strip coloured by the named players' roles" do
      expect(strip.(1)).to eq([ %w[4 red], %w[2 black], %w[9 neutral] ])
    end
  end

  context "when the best move seats are cleared" do
    let(:payloads) { [ { scope: "participation", seat: 1, field: "best_move_seats", value: [] } ] }

    it "empties the strip" do
      expect(strip.(1)).to eq([])
    end
  end

  context "when a named player's role changes" do
    let(:payloads) { [ { scope: "participation", seat: 3, field: "role_code", value: "mafia" } ] }

    it "recolours the cell naming that seat" do
      expect(strip.(1)).to eq([ %w[2 black], %w[3 black] ])
    end
  end

  context "when a named player is cleared" do
    let(:payloads) { [ { scope: "participation", seat: 2, field: "player_name", value: "" } ] }

    it "turns the cell naming that seat neutral" do
      expect(strip.(1)).to eq([ %w[2 neutral], %w[3 red] ])
    end
  end

  context "when the player who made the best move is cleared" do
    let(:payloads) { [ { scope: "participation", seat: 1, field: "player_name", value: "" } ] }

    it "removes the strip" do
      expect(strip.(1)).to eq([])
    end
  end

  context "when roles are hidden" do
    let(:payloads) { [ { scope: "game", field: "hide_roles", value: "1" } ] }
    let(:cell_backgrounds) do
      page.evaluate_script('Array.from(document.querySelectorAll("#seat-1 .overlay-best-move-cell")).map((cell) => getComputedStyle(cell).backgroundColor)')
    end

    it "paints every cell neutral" do
      expect(cell_backgrounds).to eq([ "rgba(255, 255, 255, 0.2)" ] * 2)
    end
  end
end
