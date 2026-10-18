require "rails_helper"

# Turbo restores focus by element id after the autosave stream replaces the phase; with a shared id the focus —
# and the scroll position — jumped to the topmost voting block.
RSpec.describe "Breakdown vote autosave keeps the focus" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:breakdown) { create(:game_breakdown, author: admin) }
  let(:zero_round) { breakdown.phases.find_by(position: 0) }
  let(:second_day) { day(2) }
  let(:round) { second_day.vote_rounds.first }
  let(:select_id) { "#{ActionView::RecordIdentifier.dom_id(round)}_votes_4_candidate_seat" }
  let(:summary) { "##{ActionView::RecordIdentifier.dom_id(round)}_summary" }
  let(:focused_round) { page.evaluate_script('document.activeElement.closest("div[id^=breakdown_vote_round_]")?.id') }

  before do
    nominate(zero_round, 1, 4)
    nominate(zero_round, 2, 5)
    vote(zero_round, "main")
    night(1)
    nominate(second_day, 3, 6)
    nominate(second_day, 4, 2)
    vote(second_day, "main", [ 1, 2, 3 ] => 6)

    sign_in admin
    visit edit_judge_breakdown_path(breakdown)
    find("##{select_id}").find("option[value='2']").select_option
  end

  it "keeps the focus on the changed select of the lower round" do
    expect(page).to have_css(summary, text: I18n.t("game_breakdowns.vote_outcomes.awaiting", count: 6))
    expect(focused_round).to eq(ActionView::RecordIdentifier.dom_id(round))
  end
end
