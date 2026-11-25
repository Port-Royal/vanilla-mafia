require "rails_helper"

# The status icons are white outlines drawn over the player's photo; a strong dark shadow keeps them readable on a
# light photo as well as on a dark one.
RSpec.describe "Game overlay status icon shadow" do
  let_it_be(:game) { create(:game) }
  let_it_be(:participations) do
    %i[killed_by_mafia voted_out banned].each_with_index.map do |status, index|
      create(:game_participation, game: game, player: create(:player), seat: index + 1, status: status)
    end
  end

  # Each icon's drop-shadows as [red, green, blue, alpha, blur in px].
  let(:shadows) do
    page.evaluate_script(<<~JS).map { |filter| filter.scan(/drop-shadow\(rgba?\(([^)]*)\)\s*[-\d.]+px\s+[-\d.]+px\s+([\d.]+)px\)/) }
      Array.from(document.querySelectorAll(".overlay-tiles .overlay-status-icon svg"), (icon) => getComputedStyle(icon).filter)
    JS
  end
  let(:parsed) do
    shadows.map do |icon_shadows|
      icon_shadows.map do |colour, blur|
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

  it "shadows every status icon" do
    expect(parsed.size).to eq(3)
  end

  it "stacks at least two drop-shadows on each icon" do
    expect(parsed.map(&:size)).to all(be >= 2)
  end

  it "draws every shadow in near-opaque black" do
    expect(parsed.flatten(1)).to all(match([ 0, 0, 0, be >= 0.8, anything ]))
  end

  it "spreads the widest shadow past the thin outline" do
    expect(parsed.map { |icon_shadows| icon_shadows.map(&:last).max }).to all(be >= 2)
  end
end
