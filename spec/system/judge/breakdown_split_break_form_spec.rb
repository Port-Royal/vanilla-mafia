require "rails_helper"

# A broken vote shows a hint and an optional, renamed target; other kinds keep the default label and no hint.
RSpec.describe "Breakdown move form for a broken vote" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:breakdown) { create(:game_breakdown, author: admin) }
  let(:round) { vote(breakdown.phases.find_by!(position: 0), "main") }
  let(:form) { find("##{ActionView::RecordIdentifier.dom_id(round)}") }
  let(:target_field) { form.find("[data-move-form-target='field'][data-field='target_seat']") }
  let(:hint) { form.find("[data-move-form-target='hint']", visible: :all) }

  before do
    nominate(breakdown.phases.find_by!(position: 0), 1, 4)
    round
    sign_in admin
    visit edit_judge_breakdown_path(breakdown)
    form.find("summary", text: I18n.t("game_breakdowns.editor.add_move")).click
    form.select I18n.t("game_breakdowns.move_kinds.split_break"), from: BreakdownMove.human_attribute_name(:kind)
  end

  it "explains the kind" do
    expect(hint).to have_text(I18n.t("game_breakdowns.move_kind_hints.split_break"))
  end

  it "asks for the player the vote was broken onto" do
    expect(target_field).to have_text("В кого сломал")
  end

  context "when another kind is chosen" do
    before { form.select I18n.t("game_breakdowns.move_kinds.nomination"), from: BreakdownMove.human_attribute_name(:kind) }

    it "restores the default target label" do
      expect(target_field).to have_text(BreakdownMove.human_attribute_name(:target_seat))
    end

    it "hides the hint" do
      expect(hint).not_to be_visible
    end
  end
end
