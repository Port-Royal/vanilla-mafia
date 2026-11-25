require "rails_helper"

# The nominees and the night block share one semi-transparent dark backing in the top-left corner,
# and the backing goes away when neither has anything to show, live as well.
# The test cable adapter never reaches the browser, so the specs hand a broadcast payload
# straight to the overlay controller, exactly as GameProtocolChannel would deliver it.
RSpec.describe "Game overlay night block backing" do
  let_it_be(:game) { create(:game) }

  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")'
  end
  let(:corner_style) do
    page.evaluate_script(<<~JS)
      (() => {
        const corner = document.getElementById("overlay-header-start")
        const style = getComputedStyle(corner)
        return {
          display: style.display,
          background: style.backgroundColor,
          radius: parseFloat(style.borderTopLeftRadius),
          padding: parseFloat(style.paddingTop),
          shrinksToContent: corner.getBoundingClientRect().width < document.getElementById("game-overlay").clientWidth / 2
        }
      })()
    JS
  end
  # Distance from the info block's right edge to the canvas content box: zero when it sits in the corner.
  let(:info_right_offset) do
    page.evaluate_script(<<~JS)
      (() => {
        const canvas = document.getElementById("game-overlay")
        const contentRight = canvas.getBoundingClientRect().right - parseFloat(getComputedStyle(canvas).paddingRight)
        return contentRight - document.getElementById("overlay-info").getBoundingClientRect().right
      })()
    JS
  end
  let(:shot) { { night: 1, target_seat: 5, team: "red" } }
  let(:payloads) { [] }

  before do
    visit overlay_game_path(game)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "overlay controller is not connected" unless page.evaluate_script("!!#{controller_js}")
    end
    page.execute_script("arguments[0].forEach((payload) => #{controller_js}.handleUpdate(payload))", payloads)
  end

  context "when nothing is nominated and no night is recorded" do
    it "shows no backing" do
      expect(corner_style["display"]).to eq("none")
    end

    it "keeps the info block in the right corner" do
      expect(info_right_offset).to be_within(1).of(0)
    end
  end

  context "when a night is recorded" do
    let(:payloads) { [ { scope: "shots", shots: [ shot ] } ] }

    it "puts the night block on a semi-transparent black backing" do
      expect(corner_style["background"]).to match(/\Argba\(0, 0, 0, 0\.5\d*\)\z/)
    end

    it "rounds and pads the backing" do
      expect(corner_style.values_at("radius", "padding")).to all(be > 0)
    end

    it "fits the backing to the block instead of the header width" do
      expect(corner_style["shrinksToContent"]).to be(true)
    end
  end

  context "when only the nominees are shown" do
    let(:payloads) { [ { scope: "nominees", seats: [ 4 ] } ] }

    it "shows the backing" do
      expect(corner_style["display"]).to eq("grid")
    end
  end

  context "when the nominees and the night are cleared" do
    let(:payloads) do
      [
        { scope: "nominees", seats: [ 4 ] },
        { scope: "shots", shots: [ shot ] },
        { scope: "nominees", seats: [] },
        { scope: "shots", shots: [] }
      ]
    end

    it "removes the backing" do
      expect(corner_style["display"]).to eq("none")
    end
  end

  context "when the don finds the sheriff" do
    let(:payloads) { [ { scope: "checks", checks: [ { night: 1, kind: "don", target_seat: 2, result: "sheriff" } ] } ] }
    let(:mark_image) do
      page.evaluate_script(<<~JS)
        getComputedStyle(document.querySelector("[data-row='don'] .overlay-night-cell[data-mark='sheriff']"), "::after").maskImage
      JS
    end

    it "marks the cell with the sheriff badge icon" do
      expect(mark_image).to match(%r{\Aurl\(".*/overlay/night/sheriff-\h+\.svg"\)\z})
    end
  end
end
