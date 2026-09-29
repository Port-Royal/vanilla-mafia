require "rails_helper"

# The test cable adapter never reaches the browser, so the specs hand a broadcast payload
# straight to the overlay controller, exactly as GameProtocolChannel would deliver it.
RSpec.describe "Game overlay live header" do
  let_it_be(:game) { create(:game, game_number: 3, table_number: 1, judge: "Кузнецов") }

  let(:header_texts) do
    page.evaluate_script('["overlay-table", "overlay-game-number", "overlay-judge"].map((id) => document.getElementById(id).textContent.trim())')
  end

  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")'
  end

  before do
    visit overlay_game_path(game)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "overlay controller is not connected" unless page.evaluate_script("!!#{controller_js}")
    end
    page.execute_script("arguments[0].forEach((payload) => #{controller_js}.handleUpdate(payload))", payloads)
  end

  context "when the table number and the judge change" do
    let(:payloads) do
      [
        { scope: "game", field: "table_number", value: "2" },
        { scope: "game", field: "judge", value: "Петров" }
      ]
    end

    it "updates the header without reload" do
      expect(page).to have_css("#overlay-judge", text: "Судья Петров")
      expect(header_texts).to eq([ "Стол 2", "Игра 3", "Судья Петров" ])
    end
  end

  context "when the table number and the judge are cleared" do
    let(:payloads) do
      [
        { scope: "game", field: "table_number", value: "" },
        { scope: "game", field: "judge", value: "  " }
      ]
    end

    it "hides the table and the judge" do
      expect(page).to have_no_css("#overlay-judge", text: "Судья")
      expect(header_texts).to eq([ "", "Игра 3", "" ])
    end
  end

  context "when the total is set" do
    let(:payloads) { [ { scope: "game", field: "games_total", value: "8" } ] }

    it "shows the game number out of the total" do
      expect(header_texts[1]).to eq("Игра 3/8")
    end
  end

  context "when the game number changes after the total is set" do
    let(:payloads) do
      [
        { scope: "game", field: "games_total", value: "8" },
        { scope: "game", field: "game_number", value: "4" }
      ]
    end

    it "keeps the total" do
      expect(header_texts[1]).to eq("Игра 4/8")
    end
  end

  context "when the total is cleared" do
    let(:payloads) do
      [
        { scope: "game", field: "games_total", value: "8" },
        { scope: "game", field: "games_total", value: "" }
      ]
    end

    it "shows only the game number" do
      expect(header_texts[1]).to eq("Игра 3")
    end
  end

  context "when another game field changes" do
    let(:payloads) { [ { scope: "game", field: "name", value: "Финал" } ] }

    it "leaves the header untouched" do
      expect(header_texts).to eq([ "Стол 1", "Игра 3", "Судья Кузнецов" ])
    end
  end
end
