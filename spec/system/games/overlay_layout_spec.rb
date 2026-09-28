require "rails_helper"

# Streamers size the OBS browser source to their canvas, so the overlay must lay itself out
# for any viewport: tiles change size, never proportions, and stay inside the canvas.
RSpec.describe "Game overlay layout" do
  let_it_be(:game) { create(:game) }

  let(:tile_rects) do
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".overlay-tile")).map((tile) => {
        const rect = tile.getBoundingClientRect()
        return { left: rect.left, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height }
      })
    JS
  end
  let(:viewport) { page.evaluate_script("({ width: window.innerWidth, height: window.innerHeight })") }
  let(:page_width) { page.evaluate_script("document.documentElement.scrollWidth") }
  let(:page_height) { page.evaluate_script("document.documentElement.scrollHeight") }

  before do
    width, height = viewport_size
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
    visit overlay_game_path(game)
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  [ [ 1920, 1080 ], [ 1280, 720 ], [ 2560, 1080 ], [ 1920, 600 ] ].each do |size|
    context "when the browser source is #{size.join('×')}" do
      let(:viewport_size) { size }

      it "fills the whole browser source" do
        expect(viewport.values_at("width", "height")).to eq(size)
      end

      it "renders ten tiles" do
        expect(tile_rects.size).to eq(10)
      end

      it "keeps every tile at a 3:4 portrait ratio" do
        expect(tile_rects.map { |rect| rect["width"].fdiv(rect["height"]) }).to all(be_within(0.01).of(0.75))
      end

      it "keeps the tiles inside the canvas" do
        expect(tile_rects).to all(include("left" => be >= 0, "right" => be <= viewport["width"]))
      end

      it "pins the tiles to the bottom edge" do
        expect(tile_rects.map { |rect| viewport["height"] - rect["bottom"] }).to all(be_between(0, viewport["height"] * 0.05))
      end

      it "centers the tile row" do
        expect(tile_rects.first["left"]).to be_within(1).of(viewport["width"] - tile_rects.last["right"])
      end

      it "does not overflow the canvas" do
        expect([ page_width, page_height ]).to eq([ viewport["width"], viewport["height"] ])
      end
    end
  end
end
