require "rails_helper"

RSpec.describe "Judge::Breakdowns read-only view filtered by a player" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }

  let(:breakdown) { create(:game_breakdown, author: admin, roles_mode: "closed") }
  let(:zero_round) { breakdown.phases.find_by!(position: 0) }
  let(:second_day) { day(2) }

  before do
    sign_in admin
    speech(zero_round, 3).update!(summary: "Речь третьего")
    speech(zero_round, 5).update!(summary: "Речь пятого")
    create(:breakdown_move, :check_request, breakdown_speech: speech(zero_round, 6), actor_seat: 6, target_seat: 3, text: "проверьте третьего")
    night(1, killed: 8)
    speech(second_day, 9).update!(summary: "Речь девятого")
    get judge_breakdown_path(breakdown), params: { seat: seat }
  end

  context "with a player selected" do
    let(:seat) { "3" }

    it "shows the player's own speech" do
      expect(response.body).to include("Речь третьего")
    end

    it "shows a move about them in someone else's speech" do
      expect(response.body).to include("проверьте третьего")
    end

    it "leaves out speeches that do not involve them" do
      expect(response.body).not_to include("Речь пятого")
    end

    it "hides a day with nothing of the player" do
      expect(response.body).not_to include("Речь девятого")
    end

    it "hides a night with nothing of the player" do
      expect(response.body).not_to include(I18n.t("game_breakdowns.view.killed", seat: "8"))
    end

    it "marks the selected seat and offers a reset" do
      expect(response.body).to include(%(href="#{judge_breakdown_path(breakdown)}")).and include('aria-current="true"')
    end
  end

  context "with an invalid seat" do
    let(:seat) { "42" }

    it "falls back to the full view" do
      expect(response.body).to include("Речь третьего").and include("Речь пятого").and include("Речь девятого")
    end
  end

  context "without a seat" do
    let(:seat) { nil }

    it "offers every seat as a shareable link" do
      expect(response.body).to include(%(href="#{judge_breakdown_path(breakdown, seat: 3)}"))
    end
  end
end
