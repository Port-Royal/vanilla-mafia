require "rails_helper"

# The test cable adapter never reaches the browser, so the specs hand a broadcast payload
# straight to the overlay controller, exactly as GameProtocolChannel would deliver it.
RSpec.describe "Game overlay live display settings" do
  let_it_be(:role) { create(:role, code: "sheriff") }
  let_it_be(:game) { create(:game, game_number: 3, table_number: 1, judge: "Кузнецов") }
  let_it_be(:participation) { create(:game_participation, game: game, seat: 1, role_code: "sheriff") }

  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")'
  end
  let(:shown) do
    page.evaluate_script(<<~JS)
      ["#overlay-table", "#overlay-game-number", "#overlay-judge", "#seat-1 .overlay-role-badge"].map((selector) => {
        const style = getComputedStyle(document.querySelector(selector))
        return style.display !== "none" && style.visibility !== "hidden"
      })
    JS
  end

  before do
    game.update!(settings)
    visit overlay_game_path(game)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "overlay controller is not connected" unless page.evaluate_script("!!#{controller_js}")
    end
    page.execute_script("arguments[0].forEach((payload) => #{controller_js}.handleUpdate(payload))", payloads)
  end

  context "when every setting is switched on" do
    let(:settings) { {} }
    let(:payloads) { %w[hide_roles hide_game_info hide_table_info].map { |field| { scope: "game", field: field, value: "1" } } }

    it "hides the role badges, the game number and the table but keeps the judge" do
      expect(shown).to eq([ false, false, true, false ])
    end
  end

  context "when every setting is switched off" do
    let(:settings) { { hide_roles: true, hide_game_info: true, hide_table_info: true } }
    let(:payloads) { %w[hide_roles hide_game_info hide_table_info].map { |field| { scope: "game", field: field, value: "0" } } }

    it "shows every block again" do
      expect(shown).to eq([ true, true, true, true ])
    end
  end

  context "when only the table setting is switched on" do
    let(:settings) { {} }
    let(:payloads) { [ { scope: "game", field: "hide_table_info", value: "1" } ] }

    it "hides only the table" do
      expect(shown).to eq([ false, true, true, true ])
    end
  end
end
