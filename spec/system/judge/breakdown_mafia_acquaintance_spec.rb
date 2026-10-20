require "rails_helper"

# The acquaintance saves as the judge types; the save answers with no content, so the field is not re-rendered under
# the judge's cursor (a replaced textarea keeps the text but loses the caret position).
RSpec.describe "Breakdown mafia acquaintance autosave" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }

  let(:breakdown) { create(:game_breakdown, author: admin, roles_mode: "open") }
  let(:field_id) { "game_breakdown_mafia_acquaintance" }
  let(:stored_acquaintance) do
    page.document.synchronize do
      acquaintance = breakdown.reload.mafia_acquaintance
      raise Capybara::ExpectationNotMet, "acquaintance not saved yet: #{acquaintance.inspect}" unless acquaintance == "Стреляем 3, 7, 1"

      acquaintance
    end
  end

  before do
    sign_in admin
    visit edit_judge_breakdown_path(breakdown)
    page.execute_script("window.typedField = document.getElementById(arguments[0])", field_id)
    find("##{field_id}").fill_in(with: "Стреляем 3, 7, 1")
  end

  it "saves what the judge typed" do
    expect(stored_acquaintance).to eq("Стреляем 3, 7, 1")
  end

  it "keeps the focus and the text in the field" do
    stored_acquaintance
    expect(page.evaluate_script("[document.activeElement.id, document.activeElement.value]")).to eq([ field_id, "Стреляем 3, 7, 1" ])
  end

  it "leaves the field the judge is typing in in place" do
    stored_acquaintance
    expect(page).to have_no_css("form[aria-busy]")
    expect(page.evaluate_script("window.typedField === document.getElementById(arguments[0])", field_id)).to be(true)
  end
end
