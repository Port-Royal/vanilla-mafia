require "rails_helper"

# The move form shows only the fields the chosen kind requires, plus the always-optional comment.
RSpec.describe "Breakdown move form for a check to the table" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:breakdown) { create(:game_breakdown, author: admin) }
  let(:form_speech) { speech(breakdown.phases.find_by!(position: 0), 1) }
  let(:form) { find("##{ActionView::RecordIdentifier.dom_id(form_speech)}") }
  let(:visible_fields) { form.all("[data-move-form-target='field']", visible: true).map { |field| field["data-field"] } }

  before do
    form_speech
    sign_in admin
    visit edit_judge_breakdown_path(breakdown)
    form.find("summary", text: I18n.t("game_breakdowns.editor.add_move")).click
    form.select I18n.t("game_breakdowns.move_kinds.check_claim"), from: BreakdownMove.human_attribute_name(:kind)
  end

  it "asks for the checked player and the colour, not the night" do
    expect(visible_fields).to contain_exactly("target_seat", "claimed_color", "text")
  end
end
