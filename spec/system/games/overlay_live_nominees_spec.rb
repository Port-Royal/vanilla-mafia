require "rails_helper"

# The test cable adapter never reaches the browser, so the spec hands the payload straight to the
# overlay controller, exactly as GameProtocolChannel would deliver it.
RSpec.describe "Game overlay live nominees" do
  let_it_be(:game) { create(:game) }
  let_it_be(:seated) { create(:game_participation, game:, seat: 4, player: create(:player, name: "Четвёртый")) }

  let(:controller_js) { 'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("game-overlay"), "game-overlay")' }

  before do
    visit overlay_game_path(game)
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "overlay controller is not connected" unless page.evaluate_script("!!#{controller_js}")
    end
  end

  it "shows the list a broadcast brings" do
    page.execute_script("#{controller_js}.handleUpdate({ scope: 'nominees', seats: [4] })")

    expect(page).to have_css("#overlay-nominees .overlay-nominee", text: "4 Четвёртый")
  end

  it "hides the block when the night clears the list" do
    page.execute_script("#{controller_js}.handleUpdate({ scope: 'nominees', seats: [4] })")
    page.execute_script("#{controller_js}.handleUpdate({ scope: 'nominees', seats: [] })")

    expect(page).to have_no_css("#overlay-nominees")
  end
end
