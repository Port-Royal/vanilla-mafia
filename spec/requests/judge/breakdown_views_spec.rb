require "rails_helper"

RSpec.describe "Judge::Breakdowns read-only view" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:judge) { create(:user, :judge) }
  let_it_be(:user) { create(:user) }
  let_it_be(:roles) do
    { "peace" => "Мирный", "mafia" => "Мафия", "don" => "Дон", "sheriff" => "Шериф" }
      .map { |code, name| Role.find_or_create_by!(code: code) { |role| role.name = name } }
  end

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:breakdown) { create(:game_breakdown, author: admin, title: "Финал", roles_mode: "open", judge_name: "Иванов") }
  let(:zero_round) { breakdown.phases.find_by(position: 0) }

  def assign_table_roles
    breakdown.seats.update_all(role_code: "peace")
    breakdown.seats.where(number: [ 2, 3 ]).update_all(role_code: "mafia")
    breakdown.seats.where(number: 4).update_all(role_code: "don")
    breakdown.seats.where(number: 5).update_all(role_code: "sheriff")
  end

  describe "access" do
    it "lets a judge in" do
      sign_in judge
      get judge_breakdown_path(breakdown)
      expect(response).to have_http_status(:ok)
    end

    it "lets an admin in" do
      sign_in admin
      get judge_breakdown_path(breakdown)
      expect(response).to have_http_status(:ok)
    end

    it "keeps a regular user out" do
      sign_in user
      get judge_breakdown_path(breakdown)
      expect(response).to have_http_status(:not_found)
    end

    it "sends a guest to sign in" do
      get judge_breakdown_path(breakdown)
      expect(response).to redirect_to(new_user_session_path)
    end

    context "when the toggle is off" do
      before do
        toggle.update!(enabled: false)
        sign_in admin
      end

      it "returns not found" do
        get judge_breakdown_path(breakdown)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "the page" do
    before { sign_in admin }

    it "renders the title" do
      get judge_breakdown_path(breakdown)
      expect(response.body).to include("Финал")
    end

    it "renders the metadata" do
      get judge_breakdown_path(breakdown)
      expect(response.body).to include("Иванов").and include(I18n.t("game_breakdowns.roles_modes.open"))
    end

    it "links to the editor" do
      get judge_breakdown_path(breakdown)
      expect(response.body).to include(edit_judge_breakdown_path(breakdown))
    end

    it "lists the seats with their roles" do
      assign_table_roles
      breakdown.seats.find_by(number: 5).update!(name: "Гость")

      get judge_breakdown_path(breakdown)

      expect(response.body).to include("Гость").and include("Шериф")
    end

    it "renders the phase label" do
      get judge_breakdown_path(breakdown)
      expect(response.body).to include(I18n.t("game_breakdowns.timeline.zero_round"))
    end

    it "offers no editing controls" do
      get judge_breakdown_path(breakdown)
      expect(response.body).not_to include(I18n.t("game_breakdowns.editor.add_move"))
    end

    # Every seat prints its role; without preloading that is one query per seat.
    it "loads the seat roles in a single query" do
      assign_table_roles
      role_queries = []
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        role_queries << payload[:sql] if payload[:sql].include?(%("roles"))
      end

      get judge_breakdown_path(breakdown)
      ActiveSupport::Notifications.unsubscribe(subscription)

      expect(role_queries.size).to eq(1)
    end

    it "renders the conclusion" do
      breakdown.update!(conclusion: "Скрышевали шерифа")
      get judge_breakdown_path(breakdown)
      expect(response.body).to include("Скрышевали шерифа")
    end

    it "renders the result" do
      breakdown.update!(manual_result: "mafia")
      get judge_breakdown_path(breakdown)
      expect(response.body).to include(I18n.t("game_breakdowns.results.mafia"))
    end
  end

  describe "the chronology" do
    before { sign_in admin }

    it "renders a speech with its moves" do
      nominate(zero_round, 1, 4)

      get judge_breakdown_path(breakdown)

      expect(response.body).to include(I18n.t("game_breakdowns.move_kinds.nomination"))
    end

    it "renders a vote round with its tally" do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      vote(zero_round, "main", [ 1, 2, 3, 4, 5, 6 ] => 4, [ 7, 8, 9, 10 ] => 5)

      get judge_breakdown_path(breakdown)

      expect(response.body).to include(I18n.t("game_breakdowns.vote_outcomes.eliminated"))
    end

    it "says so for a day with nothing recorded" do
      get judge_breakdown_path(breakdown)
      expect(response.body).to include(I18n.t("game_breakdowns.editor.day_placeholder"))
    end

    it "renders the warnings" do
      get judge_breakdown_path(breakdown)
      expect(response.body).to include(I18n.t("game_breakdowns.warnings.missing_sheriff"))
    end

    context "with a night" do
      let!(:first_night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "kill", killed_seat: 4) }

      before { assign_table_roles }

      it "sums the kill up in one line" do
        get judge_breakdown_path(breakdown)
        expect(response.body).to include(I18n.t("game_breakdowns.view.killed", seat: "4"))
      end

      it "adds the checks with their derived results" do
        create(:breakdown_night_action, breakdown_phase: first_night, kind: "sheriff_check", actor_seat: nil, target_seat: 2)

        get judge_breakdown_path(breakdown)

        expect(response.body).to include(I18n.t("game_breakdowns.view.check",
                                                role: I18n.t("game_breakdowns.view.sheriff_check"),
                                                seat: "2",
                                                result: I18n.t("game_breakdowns.check_results.black")))
      end

      it "reports a mafia member who did not shoot" do
        first_night.update!(night_outcome: "miss", killed_seat: nil)
        create(:breakdown_night_action, breakdown_phase: first_night, kind: "mafia_shot", actor_seat: 2, target_seat: nil)

        get judge_breakdown_path(breakdown)

        expect(response.body).to include(I18n.t("game_breakdowns.view.no_shot", actor: 2))
      end
    end
  end

  describe "the index" do
    before { sign_in admin }

    it "links each breakdown to its page" do
      breakdown

      get judge_breakdowns_path

      expect(response.body).to include(judge_breakdown_path(breakdown))
    end
  end
end
