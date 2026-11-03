require "rails_helper"

# The nickname reads on stream: a size above the canvas text, set off the tile width so it scales
# with the browser source, one line with an ellipsis for long names, and the badge kept clear of it.
RSpec.describe "Game overlay name bar" do
  let_it_be(:role_sheriff) { create(:role, code: "sheriff") }
  let_it_be(:game) { create(:game) }
  let_it_be(:participations) do
    (1..10).map do |seat|
      create(:game_participation, game: game, seat: seat, role_code: "sheriff",
                                  player: create(:player, name: "Очень длинный никнейм игрока номер #{seat}"))
    end
  end

  let(:bars) do
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".overlay-tile")).map((tile) => {
        const name = tile.querySelector(".overlay-name")
        const style = getComputedStyle(name)
        const height = (selector) => tile.querySelector(selector).getBoundingClientRect().height
        return {
          tileWidth: tile.getBoundingClientRect().width,
          fontSize: parseFloat(style.fontSize),
          lineHeight: parseFloat(style.lineHeight),
          nameHeight: height(".overlay-name"),
          seatHeight: height(".overlay-seat"),
          seatAlign: getComputedStyle(tile.querySelector(".overlay-seat")).alignItems,
          overflowing: name.scrollWidth > name.clientWidth,
          ellipsis: style.textOverflow === "ellipsis" && style.whiteSpace === "nowrap",
          badgeBottom: tile.querySelector(".overlay-role-badge").getBoundingClientRect().bottom,
          barTop: tile.querySelector(".overlay-bottom").getBoundingClientRect().top
        }
      })
    JS
  end

  before do
    width, height = viewport_size
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
    visit overlay_game_path(game)
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  [ [ 1920, 1080 ], [ 1280, 720 ] ].each do |size|
    context "when the browser source is #{size.join('×')}" do
      let(:viewport_size) { size }

      it "sets the nickname at 0.118 of the tile width" do
        expect(bars.map { |bar| bar["fontSize"].fdiv(bar["tileWidth"]) }).to all(be_within(0.002).of(0.118))
      end

      it "keeps every nickname on one line" do
        expect(bars.map { |bar| bar["nameHeight"] <= bar["lineHeight"] + 1 }).to all(be(true))
      end

      it "truncates long nicknames with an ellipsis" do
        expect(bars.map { |bar| bar.values_at("overflowing", "ellipsis") }).to all(eq([ true, true ]))
      end

      it "keeps the seat cell as tall as the nickname" do
        expect(bars.map { |bar| bar["seatHeight"] - bar["nameHeight"] }).to all(be_within(0.5).of(0))
      end

      it "centres the seat number in its taller cell" do
        expect(bars.map { |bar| bar["seatAlign"] }).to all(eq("center"))
      end

      it "keeps the role badge above the name bar" do
        expect(bars.map { |bar| bar["badgeBottom"] <= bar["barTop"] }).to all(be(true))
      end
    end
  end
end
