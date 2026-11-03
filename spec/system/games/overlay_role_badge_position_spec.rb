require "rails_helper"

# The role badge sits in the bottom-right corner of the photo, right above the best move strip
# when there is one and above the name bar otherwise, on alive and eliminated tiles alike.
RSpec.describe "Game overlay role badge position" do
  let_it_be(:role_sheriff) { create(:role, code: "sheriff") }
  let_it_be(:role_mafia) { create(:role, code: "mafia") }
  let_it_be(:role_don) { create(:role, code: "don") }
  let_it_be(:game) { create(:game) }
  let_it_be(:alive_with_best_move) do
    create(:game_participation, game: game, player: create(:player), seat: 1, role_code: "sheriff", best_move_seats: [ 2, 3 ])
  end
  let_it_be(:alive) { create(:game_participation, game: game, player: create(:player), seat: 2, role_code: "mafia") }
  let_it_be(:eliminated_with_best_move) do
    create(:game_participation, game: game, player: create(:player), seat: 3, role_code: "don", status: :killed_by_mafia, best_move_seats: [ 1, 2 ])
  end
  let_it_be(:eliminated) { create(:game_participation, game: game, player: create(:player), seat: 4, role_code: "sheriff", status: :voted_out) }

  let(:rects) do
    page.evaluate_script(<<~JS)
      [1, 2, 3, 4].map((seat) => {
        const tile = document.getElementById(`seat-${seat}`)
        const box = (element) => {
          const { left, right, top, bottom, width, height } = element.getBoundingClientRect()
          return { left, right, top, bottom, width, height }
        }
        const rect = (selector) => box(tile.querySelector(selector))
        const badge = tile.querySelector(".overlay-role-badge")
        const hit = badge.getBoundingClientRect()
        const topmost = document.elementFromPoint(hit.left + hit.width / 2, hit.top + hit.height / 2)
        return {
          tile: box(tile), badge: rect(".overlay-role-badge"),
          bestMove: rect(".overlay-best-move"), bottom: rect(".overlay-bottom"),
          badgeOnTop: badge.contains(topmost)
        }
      })
    JS
  end

  before do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false)
    visit overlay_game_path(game)
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  shared_examples "a bottom-right badge" do |seat|
    let(:tile) { rects[seat - 1]["tile"] }
    let(:badge) { rects[seat - 1]["badge"] }

    it "places the badge in the lower-right quarter of the tile" do
      expect(badge).to include("left" => be >= tile["left"] + tile["width"] / 2,
                               "top" => be >= tile["top"] + tile["height"] / 2,
                               "right" => be <= tile["right"], "bottom" => be <= tile["bottom"])
    end

    it "keeps the badge visible above the photo" do
      expect(rects[seat - 1]["badgeOnTop"]).to be(true)
    end
  end

  shared_examples "a badge above the strip" do |seat|
    it "sits right above the best move strip" do
      expect(rects[seat - 1]["badge"]["bottom"]).to be_between(rects[seat - 1]["bestMove"]["top"] - 10, rects[seat - 1]["bestMove"]["top"])
    end
  end

  shared_examples "a badge above the name bar" do |seat|
    it "sits right above the name bar" do
      expect(rects[seat - 1]["badge"]["bottom"]).to be_between(rects[seat - 1]["bottom"]["top"] - 10, rects[seat - 1]["bottom"]["top"])
    end
  end

  context "when the player is alive with a best move" do
    it_behaves_like "a bottom-right badge", 1
    it_behaves_like "a badge above the strip", 1
  end

  context "when the player is alive without a best move" do
    it_behaves_like "a bottom-right badge", 2
    it_behaves_like "a badge above the name bar", 2
  end

  context "when the player is eliminated with a best move" do
    it_behaves_like "a bottom-right badge", 3
    it_behaves_like "a badge above the strip", 3
  end

  context "when the player is eliminated without a best move" do
    it_behaves_like "a bottom-right badge", 4
    it_behaves_like "a badge above the name bar", 4
  end
end
