require "rails_helper"

# The nickname reads on stream: a size above the canvas text, set off the tile width so it scales
# with the browser source. A name too long for the bar shrinks until it fits on one line; only a
# name too long even at the smallest size falls back to the ellipsis. The bar keeps one height.
RSpec.describe "Game overlay name bar" do
  let_it_be(:role_sheriff) { create(:role, code: "sheriff") }
  let_it_be(:game) { create(:game) }
  let_it_be(:names) do
    {
      1 => "Кот",
      2 => "Младшенький",
      3 => "Профессионалка",
      4 => "Шерлок-Холмсыч",
      5 => "Очень длинный никнейм игрока номер пять"
    }
  end
  let_it_be(:participations) do
    names.map do |seat, name|
      create(:game_participation, game: game, seat: seat, role_code: "sheriff", player: create(:player, name: name))
    end
  end

  let(:base_ratio) { 0.132 }
  let(:min_ratio) { 0.132 * 0.6 }
  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")'
  end
  let(:fitted) { settled_bars }

  def bars
    page.evaluate_script(<<~JS).to_h { |bar| [ bar["seat"], bar ] }
      Array.from(document.querySelectorAll(".overlay-tile")).map((tile) => {
        const name = tile.querySelector(".overlay-name")
        const style = getComputedStyle(name)
        const height = (selector) => tile.querySelector(selector).getBoundingClientRect().height
        const tileWidth = tile.getBoundingClientRect().width
        const text = document.createRange()
        text.selectNodeContents(name)
        const room = name.getBoundingClientRect().width - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
        return {
          seat: Number(tile.dataset.seat),
          size: parseFloat(style.fontSize) / tileWidth,
          fit: name.style.getPropertyValue("--overlay-name-fit"),
          padding: [style.paddingLeft, style.paddingRight].map((padding) => parseFloat(padding) / tileWidth),
          barHeight: height(".overlay-bottom") / tileWidth,
          nameHeight: height(".overlay-name") / tileWidth,
          seatHeight: height(".overlay-seat") / tileWidth,
          seatAlign: getComputedStyle(tile.querySelector(".overlay-seat")).alignItems,
          overflowing: text.getBoundingClientRect().width > room + 0.01,
          ellipsis: style.textOverflow === "ellipsis" && style.whiteSpace === "nowrap",
          badgeBottom: tile.querySelector(".overlay-role-badge").getBoundingClientRect().bottom,
          barTop: tile.querySelector(".overlay-bottom").getBoundingClientRect().top
        }
      })
    JS
  end

  def settled_bars
    page.document.synchronize do
      current = bars
      raise Capybara::ExpectationNotMet, "nicknames are not fitted yet" if current.dig(2, "size") >= base_ratio - 0.002

      current
    end
  end

  def refitted_bars
    page.document.synchronize do
      current = bars
      raise Capybara::ExpectationNotMet, "nicknames are not refitted yet" if current.values.any? { |bar| bar["fit"] == stale_fit }

      current
    end
  end

  before do
    resize_to(*viewport_size)
    visit overlay_game_path(game)
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  def resize_to(width, height)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
  end

  shared_examples "a fitted name bar" do
    it "sets a short nickname at 0.132 of the tile width" do
      expect(fitted.dig(1, "size")).to be_within(0.002).of(base_ratio)
    end

    it "shows 11 to 14 character nicknames in full" do
      expect(fitted.values_at(2, 3, 4).map { |bar| bar["overflowing"] }).to all(be(false))
    end

    it "shrinks those nicknames to fit, no smaller than the minimum" do
      expect(fitted.values_at(2, 3, 4).map { |bar| bar["size"] }).to all(be_between(min_ratio - 0.002, base_ratio - 0.002))
    end

    it "sets a nickname too long even at the minimum at the minimum size" do
      expect(fitted.dig(5, "size")).to be_within(0.002).of(min_ratio)
    end

    it "truncates that nickname with an ellipsis" do
      expect(fitted[5].values_at("overflowing", "ellipsis")).to eq([ true, true ])
    end

    it "keeps the same side padding for every nickname, whatever its size" do
      expect(fitted.values.map { |bar| bar["padding"] }).to all(match([ be_within(0.0005).of(fitted.dig(1, "padding", 0)) ] * 2))
    end

    it "keeps every name bar at one height, whatever the nickname" do
      expect(fitted.values.map { |bar| bar["barHeight"] }).to all(be_within(0.002).of(0.185))
    end

    it "keeps every nickname on one line inside the bar" do
      expect(fitted.values.map { |bar| bar["nameHeight"] - bar["barHeight"] }).to all(be <= 0.002)
    end

    it "keeps the seat cell as tall as the bar" do
      expect(fitted.values.map { |bar| bar["seatHeight"] - bar["barHeight"] }).to all(be_within(0.002).of(0))
    end

    it "centres the seat number in its cell" do
      expect(fitted.values.map { |bar| bar["seatAlign"] }).to all(eq("center"))
    end

    it "keeps the role badge above the name bar" do
      expect(fitted.values.map { |bar| bar["badgeBottom"] <= bar["barTop"] }).to all(be(true))
    end
  end

  [ [ 1920, 1080 ], [ 1280, 720 ] ].each do |size|
    context "when the browser source is #{size.join('×')}" do
      let(:viewport_size) { size }

      it_behaves_like "a fitted name bar"
    end
  end

  # Fit factors scale with the tile width, so the ones chosen at 1920×1080 would still pass at 1280×720. Each name gets
  # a factor the fitting never picks before the resize; only a refit on resize replaces it.
  context "when the browser source is resized" do
    let(:viewport_size) { [ 1920, 1080 ] }
    let(:stale_fit) { "0.3" }
    let(:fitted) { refitted_bars }

    before do
      settled_bars
      page.execute_script(<<~JS, stale_fit)
        document.querySelectorAll(".overlay-name").forEach((name) => name.style.setProperty("--overlay-name-fit", arguments[0]))
      JS
      resize_to(1280, 720)
    end

    it_behaves_like "a fitted name bar"
  end

  context "when a short nickname is renamed live to a long one" do
    let(:viewport_size) { [ 1920, 1080 ] }

    before do
      settled_bars
      page.execute_script("#{controller_js}.handleUpdate(arguments[0])", { scope: "participation", seat: 1, field: "player_name", value: "Младшенький" })
    end

    it "shrinks it to fit" do
      expect(bars[1].values_at("size", "overflowing")).to eq(bars[2].values_at("size", "overflowing"))
    end
  end

  context "when a long nickname is renamed live to a short one" do
    let(:viewport_size) { [ 1920, 1080 ] }

    before do
      settled_bars
      page.execute_script("#{controller_js}.handleUpdate(arguments[0])", { scope: "participation", seat: 2, field: "player_name", value: "Кот" })
    end

    it "brings it back to the base size" do
      expect(bars.dig(2, "size")).to be_within(0.002).of(base_ratio)
    end
  end
end
