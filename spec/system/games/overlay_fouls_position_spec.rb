require "rails_helper"

# Fouls are red bars and technical fouls grey bars, in the top-left corner of the tile, clear of the status icon in
# the top-right. A wider gap separates the red group from the grey one; a seat with grey bars only gets no extra gap.
RSpec.describe "Game overlay fouls position" do
  let_it_be(:game) { create(:game) }
  let_it_be(:seats) do
    (1..3).map { |seat| create(:game_participation, game: game, player: create(:player), seat: seat) }
  end
  let_it_be(:events) do
    position = 0
    { 1 => %w[foul foul tech], 2 => %w[tech tech], 3 => %w[foul foul] }.each do |seat, kinds|
      kinds.each { |kind| create(:game_protocol_event, game: game, position: position += 1, kind: kind, target_seats: [ seat ]) }
    end
  end

  let(:rects) do
    page.evaluate_script(<<~JS)
      [1, 2, 3].map((seat) => {
        const tile = document.getElementById(`seat-${seat}`)
        const box = (element) => {
          const { left, right, top, bottom, width, height } = element.getBoundingClientRect()
          return { left, right, top, bottom, width, height }
        }
        return {
          tile: box(tile),
          fouls: box(tile.querySelector(".overlay-fouls")),
          status: box(tile.querySelector(".overlay-status-icon")),
          bars: Array.from(tile.querySelectorAll(".overlay-fouls > span"), box)
        }
      })
    JS
  end

  before do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false)
    visit overlay_game_path(game)
  end

  after { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  def gaps(seat)
    rects[seat - 1]["bars"].each_cons(2).map { |left, right| right["left"] - left["right"] }
  end

  shared_examples "a top-left fouls block" do |seat|
    let(:tile) { rects[seat - 1]["tile"] }
    let(:fouls) { rects[seat - 1]["fouls"] }

    it "places the block in the top-left corner of the tile" do
      expect(fouls).to include("left" => be_between(tile["left"], tile["left"] + tile["width"] / 4),
                               "top" => be_between(tile["top"], tile["top"] + tile["height"] / 8))
    end

    it "keeps the block left of the status icon" do
      expect(fouls["right"]).to be < rects[seat - 1]["status"]["left"]
    end
  end

  context "when the seat has fouls and technical fouls" do
    it_behaves_like "a top-left fouls block", 1

    it "separates the grey group from the red one by a wider gap" do
      expect(gaps(1)).to match([ be > 0, be > gaps(1).first + 5 ])
    end
  end

  context "when the seat has technical fouls only" do
    it_behaves_like "a top-left fouls block", 2

    it "starts the grey bars at the left edge of the block" do
      expect(rects[1]["bars"].first["left"]).to be_within(1).of(rects[1]["fouls"]["left"])
    end

    it "keeps the same gap as between red bars" do
      expect(gaps(2).first).to be_within(1).of(gaps(3).first)
    end
  end

  context "when the seat has fouls only" do
    it_behaves_like "a top-left fouls block", 3

    it "draws evenly spaced bars" do
      expect(gaps(3)).to match([ be > 0 ])
    end
  end
end
