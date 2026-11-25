require "rails_helper"

# The test cable adapter never reaches the browser, so the specs hand a broadcast payload
# straight to the overlay controller, exactly as GameProtocolChannel would deliver it.
RSpec.describe "Game overlay live header" do
  let_it_be(:competition) { create(:competition, name: "Кубок Осени") }
  let_it_be(:game) { create(:game, competition:, game_number: 3, table_number: 1, judge: "Кузнецов") }

  let(:header_texts) do
    page.evaluate_script('["overlay-table", "overlay-game-number", "overlay-judge"].map((id) => document.getElementById(id).textContent.trim())')
  end
  let(:shown_rows) do
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("#overlay-info .overlay-info-row")]
        .filter((row) => getComputedStyle(row).display !== "none")
        .map((row) => [...row.children].map((cell) => cell.textContent.trim()))
    JS
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
      expect(page).to have_css("#overlay-judge", text: "Петров")
      expect(shown_rows).to eq([ %w[Стол 2], %w[Игра 3], [ "Турнир", "Кубок Осени" ], %w[Судья Петров] ])
    end
  end

  context "when the table number and the judge are cleared" do
    let(:payloads) do
      [
        { scope: "game", field: "table_number", value: "" },
        { scope: "game", field: "judge", value: "  " }
      ]
    end

    it "leaves out the table and the judge rows" do
      expect(page).to have_no_css("#overlay-judge-row")
      expect(shown_rows).to eq([ %w[Игра 3], [ "Турнир", "Кубок Осени" ] ])
    end
  end

  context "when the competition changes" do
    let(:payloads) { [ { scope: "game", field: "competition", value: "Кубок Зимы" } ] }

    it "shows the new tournament without reload" do
      expect(page).to have_css("#overlay-tournament", text: "Кубок Зимы")
      expect(shown_rows).to eq([ %w[Стол 1], %w[Игра 3], [ "Турнир", "Кубок Зимы" ], %w[Судья Кузнецов] ])
    end
  end

  context "when the total is set" do
    let(:payloads) { [ { scope: "game", field: "games_total", value: "8" } ] }

    it "shows the game number out of the total" do
      expect(header_texts[1]).to eq("3/8")
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
      expect(header_texts[1]).to eq("4/8")
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
      expect(header_texts[1]).to eq("3")
    end
  end

  context "when another game field changes" do
    let(:payloads) { [ { scope: "game", field: "name", value: "Финал" } ] }

    it "leaves the header untouched" do
      expect(header_texts).to eq(%w[1 3 Кузнецов])
    end
  end
end
