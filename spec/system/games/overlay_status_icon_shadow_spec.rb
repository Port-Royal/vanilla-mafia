require "rails_helper"

# The status icons are outline icons drawn over the player's photo; a strong dark shadow keeps them readable on a
# light photo as well as on a dark one, whether the icon came with the page or arrived live.
RSpec.describe "Game overlay status icon shadow" do
  let_it_be(:game) { create(:game) }
  let_it_be(:participations) do
    %i[killed_by_mafia voted_out banned alive].each_with_index.map do |status, index|
      create(:game_participation, game: game, player: create(:player), seat: index + 1, status: status)
    end
  end

  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")'
  end
  let(:filters) do
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".overlay-tiles .overlay-status-icon svg"), (icon) => getComputedStyle(icon).filter)
    JS
  end
  # Each icon's drop-shadows as [red, green, blue, alpha, blur in px].
  let(:shadows) do
    filters.map do |filter|
      filter.scan(/drop-shadow\(rgba?\(([^)]*)\)\s*[-\d.]+px\s+[-\d.]+px\s+([\d.]+)px\)/).map do |colour, blur|
        red, green, blue, alpha = colour.split(",").map(&:to_f)
        [ red, green, blue, alpha || 1.0, blur.to_f ]
      end
    end
  end

  before do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false)
    visit overlay_game_path(game)
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  shared_examples "strongly shadowed status icons" do |count|
    it "renders an icon for every eliminated seat" do
      expect(filters.size).to eq(count)
    end

    it "gives every icon a drop-shadow the spec can read" do
      expect(shadows).to all(be_present)
    end

    it "stacks at least two drop-shadows on each icon" do
      expect(shadows.map(&:size)).to all(be >= 2)
    end

    it "draws every shadow in near-opaque black" do
      expect(shadows.flatten(1)).to all(match([ 0, 0, 0, be >= 0.8, anything ]))
    end

    it "spreads the widest shadow past the thin outline" do
      expect(shadows.map { |icon_shadows| icon_shadows.map(&:last).max }).to all(be >= 2)
    end
  end

  context "when the icons come with the page" do
    it_behaves_like "strongly shadowed status icons", 3
  end

  context "when a status arrives live" do
    before do
      page.execute_script("#{controller_js}.handleUpdate(arguments[0])", { scope: "participation", seat: 4, field: "status", value: "voted_out" })
      page.assert_selector("#seat-4 .overlay-status-icon svg")
    end

    it_behaves_like "strongly shadowed status icons", 4
  end
end
