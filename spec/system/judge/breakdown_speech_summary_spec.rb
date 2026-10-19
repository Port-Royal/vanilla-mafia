require "rails_helper"

# The summary saves as the judge types; the save answers with no content, so the field keeps its focus and text.
RSpec.describe "Breakdown speech summary autosave" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }

  let(:breakdown) { create(:game_breakdown, author: admin) }
  let(:regular) { speech(breakdown.phases.find_by!(position: 0), 1) }
  let(:field_id) { "#{ActionView::RecordIdentifier.dom_id(regular)}_breakdown_speech_summary" }
  let(:stored_summary) do
    page.document.synchronize do
      summary = regular.reload.summary
      raise Capybara::ExpectationNotMet, "summary not saved yet: #{summary.inspect}" unless summary == "Подозревает 7"

      summary
    end
  end

  before do
    regular
    sign_in admin
    visit edit_judge_breakdown_path(breakdown)
    find("##{field_id}").fill_in(with: "Подозревает 7")
  end

  it "saves what the judge typed" do
    expect(stored_summary).to eq("Подозревает 7")
  end

  it "keeps the focus and the text in the field" do
    stored_summary
    expect(page.evaluate_script("[document.activeElement.id, document.activeElement.value]")).to eq([ field_id, "Подозревает 7" ])
  end
end
