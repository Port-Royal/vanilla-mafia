require "rails_helper"

RSpec.describe "Judge::Breakdowns night editing" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:roles) do
    { "peace" => "Мирный", "mafia" => "Мафия", "don" => "Дон", "sheriff" => "Шериф" }
      .map { |code, name| Role.find_or_create_by!(code: code) { |role| role.name = name } }
  end

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:breakdown) { create(:game_breakdown, author: admin, roles_mode: "open") }
  let!(:first_night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1) }

  def assign_table_roles
    breakdown.seats.update_all(role_code: "peace")
    breakdown.seats.where(number: [ 2, 3 ]).update_all(role_code: "mafia")
    breakdown.seats.where(number: 4).update_all(role_code: "don")
    breakdown.seats.where(number: 5).update_all(role_code: "sheriff")
  end

  before { sign_in admin }

  describe "GET /judge/breakdowns/:id/edit" do
    before { assign_table_roles }

    it "renders the night outcome select" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include('name="breakdown_phase[outcome]"')
    end

    # Outcome and killed seat are one choice, so a kill can never be submitted without its seat.
    it "offers a kill option per alive seat" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include('value="kill:7"').and include('value="miss"')
    end

    it "offers no separate killed seat field" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).not_to include('name="breakdown_phase[killed_seat]"')
    end

    context "when the night is a kill" do
      before { first_night.update!(night_outcome: "kill", killed_seat: 7) }

      it "preselects the recorded kill" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body).to include(%(<option selected="selected" value="kill:7">))
      end

      it "records no shots, since the shot is implied by the kill" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body).not_to include(I18n.t("game_breakdowns.editor.mafia_shots"))
      end
    end

    context "when the night is a miss" do
      before { first_night.update!(night_outcome: "miss") }

      it "offers a shot row for every alive mafia member" do
        get edit_judge_breakdown_path(breakdown)

        expect(response.body).to include('name="shots[2]"').and include('name="shots[3]"').and include('name="shots[4]"')
      end

      it "offers no shot row for a red seat" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body).not_to include('name="shots[5]"')
      end

      it "says so when no mafia roles are set" do
        breakdown.seats.update_all(role_code: nil)

        get edit_judge_breakdown_path(breakdown)

        expect(response.body).to include(I18n.t("game_breakdowns.editor.no_shooters"))
      end
    end

    it "offers the don and sheriff checks" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include('name="checks[don_check]"').and include('name="checks[sheriff_check]"')
    end

    it "hides a check whose role is not set" do
      breakdown.seats.where(number: 5).update_all(role_code: "peace")

      get edit_judge_breakdown_path(breakdown)

      expect(response.body).not_to include('name="checks[sheriff_check]"')
    end

    context "when the checker was eliminated earlier" do
      before do
        create(:breakdown_phase, game_breakdown: breakdown, position: 2)
        create(:breakdown_phase, game_breakdown: breakdown, position: 3)
        first_night.update!(night_outcome: "kill", killed_seat: 5)
      end

      it "hides the sheriff check on the later night" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body.scan(/name="checks\[sheriff_check\]"/).size).to eq(1)
      end
    end

    it "shows the derived result of a recorded check" do
      create(:breakdown_night_action, breakdown_phase: first_night, kind: "sheriff_check", actor_seat: nil, target_seat: 2)

      get edit_judge_breakdown_path(breakdown)

      expect(response.body).to include(I18n.t("game_breakdowns.check_results.black"))
    end

    context "when the roles are hidden" do
      let(:breakdown) { create(:game_breakdown, author: admin, roles_mode: "closed") }

      before { first_night.update!(night_outcome: "miss") }

      it "still offers the outcome" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body).to include('name="breakdown_phase[outcome]"')
      end

      it "offers no shots" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body).not_to include('name="shots[2]"')
      end

      it "offers no checks" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body).not_to include('name="checks[don_check]"')
      end
    end
  end

  describe "PATCH /judge/breakdowns/:breakdown_id/phases/:id" do
    before { assign_table_roles }

    it "records a kill" do
      patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "kill:7" } }
      expect(first_night.reload).to have_attributes(night_outcome: "kill", killed_seat: 7)
    end

    it "records a miss" do
      patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "miss" } }
      expect(first_night.reload).to have_attributes(night_outcome: "miss", killed_seat: nil)
    end

    it "turns a recorded miss into a kill in one step" do
      first_night.update!(night_outcome: "miss")

      patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "kill:7" } }

      expect(first_night.reload).to have_attributes(night_outcome: "kill", killed_seat: 7)
    end

    it "drops the killed seat when the outcome becomes a miss" do
      first_night.update!(night_outcome: "kill", killed_seat: 7)

      patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "miss" } }

      expect(first_night.reload).to have_attributes(night_outcome: "miss", killed_seat: nil)
    end

    it "clears the outcome when nothing is recorded" do
      first_night.update!(night_outcome: "kill", killed_seat: 7)

      patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "" } }

      expect(first_night.reload).to have_attributes(night_outcome: nil, killed_seat: nil)
    end

    it "records the shots" do
      patch judge_breakdown_phase_path(breakdown, first_night),
            params: { breakdown_phase: { outcome: "miss" }, shots: { "2" => "7", "3" => "none" } }

      expect(first_night.night_actions.reload.map { |a| [ a.actor_seat, a.target_seat ] })
        .to contain_exactly([ 2, 7 ], [ 3, nil ])
    end

    it "records the checks" do
      patch judge_breakdown_phase_path(breakdown, first_night),
            params: { breakdown_phase: { outcome: "miss" }, checks: { "don_check" => "5", "sheriff_check" => "2" } }

      expect(first_night.night_actions.reload.map { |a| [ a.kind, a.target_seat ] })
        .to contain_exactly([ "don_check", 5 ], [ "sheriff_check", 2 ])
    end

    it "drops the shots when the night turns out to be a kill" do
      create(:breakdown_night_action, breakdown_phase: first_night, kind: "mafia_shot", actor_seat: 2, target_seat: 7)

      patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "kill:4" } }

      expect(first_night.night_actions.reload.select(&:mafia_shot?)).to be_empty
    end

    it "keeps the checks when the night turns out to be a kill" do
      create(:breakdown_night_action, breakdown_phase: first_night, kind: "don_check", actor_seat: nil, target_seat: 5)

      patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "kill:4" } }

      expect(first_night.night_actions.reload.map(&:kind)).to eq([ "don_check" ])
    end

    it "ignores shots submitted for a kill" do
      patch judge_breakdown_phase_path(breakdown, first_night),
            params: { breakdown_phase: { outcome: "kill:4" }, shots: { "2" => "7" } }

      expect(first_night.night_actions.reload.select(&:mafia_shot?)).to be_empty
    end

    it "re-renders the edited phase and the ones after it" do
      later_day = create(:breakdown_phase, game_breakdown: breakdown, position: 2)

      patch judge_breakdown_phase_path(breakdown, first_night),
            params: { breakdown_phase: { outcome: "kill:7" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(first_night)}"))
        .and include(%(target="#{ActionView::RecordIdentifier.dom_id(later_day)}"))
    end

    it "redirects back to the editor" do
      patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "miss" } }
      expect(response).to redirect_to(edit_judge_breakdown_path(breakdown))
    end

    context "when the roles are hidden" do
      let(:breakdown) { create(:game_breakdown, author: admin, roles_mode: "closed") }

      it "stores the outcome" do
        patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "miss" } }
        expect(first_night.reload.night_outcome).to eq("miss")
      end

      it "stores no night internals" do
        patch judge_breakdown_phase_path(breakdown, first_night),
              params: { breakdown_phase: { outcome: "miss" }, shots: { "2" => "7" } }

        expect(first_night.night_actions.reload).to be_empty
      end
    end

    it "does not reach a phase of another breakdown" do
      other = create(:game_breakdown, author: admin)

      patch judge_breakdown_phase_path(other, first_night), params: { breakdown_phase: { outcome: "miss" } }

      expect(response).to have_http_status(:not_found)
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "miss" } }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the user is a regular user" do
      before { sign_in user }

      it "returns not found" do
        patch judge_breakdown_phase_path(breakdown, first_night), params: { breakdown_phase: { outcome: "miss" } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
