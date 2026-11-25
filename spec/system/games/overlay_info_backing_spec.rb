require "rails_helper"

# The game info block sits on a semi-transparent dark backing so it reads over any stream
# background, and the backing goes away with the last shown row, live as well.
# The test cable adapter never reaches the browser, so the specs hand a broadcast payload
# straight to the overlay controller, exactly as GameProtocolChannel would deliver it.
RSpec.describe "Game overlay info backing" do
  let_it_be(:game) { create(:game, game_number: 3, table_number: 1, judge: "Кузнецов") }

  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")'
  end
  let(:info_style) do
    page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.getElementById("overlay-info"))
        const canvasFontSize = parseFloat(getComputedStyle(document.getElementById("game-overlay")).fontSize)
        return {
          display: style.display,
          background: style.backgroundColor,
          radius: parseFloat(style.borderTopLeftRadius),
          padding: parseFloat(style.paddingTop),
          scale: parseFloat(style.fontSize) / canvasFontSize
        }
      })()
    JS
  end
  # Nothing in the app hides the tournament row yet, so the specs hide it by hand to reach "all info hidden".
  let(:tournament_hidden) { false }
  let(:payloads) { [] }

  before do
    visit overlay_game_path(game)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "overlay controller is not connected" unless page.evaluate_script("!!#{controller_js}")
    end
    page.execute_script('document.getElementById("overlay-tournament-row").hidden = true') if tournament_hidden
    page.execute_script("arguments[0].forEach((payload) => #{controller_js}.handleUpdate(payload))", payloads)
  end

  context "when the info is shown" do
    it "puts the info on a semi-transparent black backing" do
      expect(info_style["background"]).to match(/\Argba\(0, 0, 0, 0\.5\d*\)\z/)
    end

    it "rounds and pads the backing" do
      expect(info_style.values_at("radius", "padding")).to all(be > 0)
    end

    it "sets the info text larger than the rest of the overlay" do
      expect(info_style["scale"]).to be_within(0.01).of(1.2)
    end
  end

  context "when the values are cleared and the settings hide the rest" do
    let(:tournament_hidden) { true }
    let(:payloads) do
      [
        { scope: "game", field: "table_number", value: "" },
        { scope: "game", field: "judge", value: "" },
        { scope: "game", field: "hide_game_info", value: "1" }
      ]
    end

    it "removes the backing" do
      expect(info_style["display"]).to eq("none")
    end
  end

  context "when the settings hide both the table and the game" do
    let(:tournament_hidden) { true }
    let(:payloads) do
      [
        { scope: "game", field: "judge", value: "" },
        { scope: "game", field: "hide_game_info", value: "1" },
        { scope: "game", field: "hide_table_info", value: "1" }
      ]
    end

    it "removes the backing" do
      expect(info_style["display"]).to eq("none")
    end
  end

  context "when a row comes back after every row was hidden" do
    let(:tournament_hidden) { true }
    let(:payloads) do
      [
        { scope: "game", field: "table_number", value: "" },
        { scope: "game", field: "judge", value: "" },
        { scope: "game", field: "hide_game_info", value: "1" },
        { scope: "game", field: "judge", value: "Петров" }
      ]
    end

    it "brings the backing back" do
      expect(info_style["display"]).to eq("grid")
    end
  end
end
