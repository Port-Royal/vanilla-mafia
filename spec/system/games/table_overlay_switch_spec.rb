require "rails_helper"

# The test cable adapter never reaches the browser, so the spec hands the announcement straight to
# the table overlay controller, exactly as TableOverlayChannel would deliver it.
RSpec.describe "Table overlay switching games" do
  let_it_be(:first) { create(:game, table_number: 2, played_on: Date.current, judge: "Первый", created_at: 1.hour.ago) }

  let(:controller_js) do
    'window.Stimulus.getControllerForElementAndIdentifier(document.getElementById("table-overlay"), "table-overlay")'
  end

  before do
    visit table_overlay_path(number: 2)
    expect(page).to have_css("#overlay-judge", text: "Первый")
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "table overlay controller is not connected" unless page.evaluate_script("!!#{controller_js}")
    end
  end

  context "when the next game at the table starts" do
    let!(:second) { create(:game, table_number: 2, played_on: Date.current, judge: "Второй") }

    before { page.execute_script("#{controller_js}.received(arguments[0])", { game_id: second.id }) }

    it "reloads onto the new game" do
      expect(page).to have_css("#overlay-judge", text: "Второй")
    end
  end

  context "when the current game is announced again" do
    before do
      page.execute_script("document.getElementById('overlay-judge').dataset.marker = 'kept'")
      page.execute_script("#{controller_js}.received(arguments[0])", { game_id: first.id })
    end

    it "keeps the page" do
      expect(page).to have_css("#overlay-judge[data-marker='kept']", text: "Первый")
    end
  end
end
