require "rails_helper"

RSpec.describe "Judge::Breakdowns" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:judge) { create(:user, :judge) }
  let_it_be(:user) { create(:user) }

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }

  describe "GET /judge/breakdowns" do
    let_it_be(:breakdown) { create(:game_breakdown, title: "Финал сезона", author: admin) }

    context "when user is admin" do
      before { sign_in admin }

      it "returns success" do
        get judge_breakdowns_path
        expect(response).to have_http_status(:ok)
      end

      it "lists existing breakdowns" do
        get judge_breakdowns_path
        expect(response.body).to include("Финал сезона")
      end

      it "links to the editor" do
        get judge_breakdowns_path
        expect(response.body).to include(edit_judge_breakdown_path(breakdown))
      end
    end

    context "when user is judge" do
      before { sign_in judge }

      it "returns success" do
        get judge_breakdowns_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is a regular user" do
      before { sign_in user }

      it "returns not found" do
        get judge_breakdowns_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get judge_breakdowns_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the toggle is off" do
      before do
        toggle.update!(enabled: false)
        sign_in admin
      end

      it "returns not found" do
        get judge_breakdowns_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the toggle is missing" do
      before do
        toggle.destroy!
        sign_in admin
      end

      it "returns not found" do
        get judge_breakdowns_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /judge/breakdowns/new" do
    before { sign_in admin }

    it "returns success" do
      get new_judge_breakdown_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the form title" do
      get new_judge_breakdown_path
      expect(response.body).to include(I18n.t("game_breakdowns.new.title"))
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        get new_judge_breakdown_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /judge/breakdowns" do
    before { sign_in admin }

    let(:params) { { game_breakdown: { title: "Разбор", roles_mode: "closed", played_on: "2026-09-14", source: "Кубок" } } }

    it "creates a breakdown" do
      expect { post judge_breakdowns_path, params: params }.to change(GameBreakdown, :count).by(1)
    end

    it "sets the current user as author" do
      post judge_breakdowns_path, params: params
      expect(GameBreakdown.last.author).to eq(admin)
    end

    it "stores the submitted attributes" do
      post judge_breakdowns_path, params: params
      expect(GameBreakdown.last).to have_attributes(title: "Разбор", roles_mode: "closed", source: "Кубок")
    end

    it "creates ten seats" do
      post judge_breakdowns_path, params: params
      expect(GameBreakdown.last.seats.count).to eq(10)
    end

    it "creates the zero round" do
      post judge_breakdowns_path, params: params
      expect(GameBreakdown.last.phases.map(&:position)).to eq([ 0 ])
    end

    it "redirects to the editor" do
      post judge_breakdowns_path, params: params
      expect(response).to redirect_to(edit_judge_breakdown_path(GameBreakdown.last))
    end

    context "when a game is linked" do
      let_it_be(:role) { create(:role, code: "don", name: "Дон") }
      let_it_be(:player) { create(:player, name: "Тестовый") }
      let_it_be(:game) { create(:game) }
      let_it_be(:participation) { create(:game_participation, game: game, seat: 3, player: player, role_code: "don") }

      it "pre-fills seats from the game protocol" do
        post judge_breakdowns_path, params: { game_breakdown: { title: "Разбор", game_id: game.id } }

        expect(GameBreakdown.last.seats.find_by(number: 3)).to have_attributes(name: "Тестовый", player_id: player.id, role_code: "don")
      end
    end

    context "when the title is blank" do
      it "does not create a breakdown" do
        expect { post judge_breakdowns_path, params: { game_breakdown: { title: "" } } }.not_to change(GameBreakdown, :count)
      end

      it "renders the form again" do
        post judge_breakdowns_path, params: { game_breakdown: { title: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        post judge_breakdowns_path, params: params
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /judge/breakdowns/:id/edit" do
    let_it_be(:breakdown) { create(:game_breakdown, title: "Разбор", author: admin) }

    before { sign_in admin }

    it "returns success" do
      get edit_judge_breakdown_path(breakdown)
      expect(response).to have_http_status(:ok)
    end

    it "renders the breakdown title" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include("Разбор")
    end

    it "renders the zero round label" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include(I18n.t("game_breakdowns.timeline.zero_round"))
    end

    it "renders a row for every seat" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body.scan(/data-seat-number=/).size).to eq(10)
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        get edit_judge_breakdown_path(breakdown)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /judge/breakdowns/:id" do
    let_it_be(:breakdown) { create(:game_breakdown, author: admin) }

    before { sign_in admin }

    it "updates the attribute" do
      patch judge_breakdown_path(breakdown), params: { game_breakdown: { judge_name: "Иванов" } }
      expect(breakdown.reload.judge_name).to eq("Иванов")
    end

    it "updates the roles mode" do
      patch judge_breakdown_path(breakdown), params: { game_breakdown: { roles_mode: "closed" } }
      expect(breakdown.reload.roles_mode).to eq("closed")
    end

    it "updates the conclusion" do
      patch judge_breakdown_path(breakdown), params: { game_breakdown: { conclusion: "Скрышевали шерифа" } }
      expect(breakdown.reload.conclusion).to eq("Скрышевали шерифа")
    end

    it "updates the manual result" do
      patch judge_breakdown_path(breakdown), params: { game_breakdown: { manual_result: "mafia" } }
      expect(breakdown.reload.manual_result).to eq("mafia")
    end

    it "redirects back to the editor" do
      patch judge_breakdown_path(breakdown), params: { game_breakdown: { judge_name: "Иванов" } }
      expect(response).to redirect_to(edit_judge_breakdown_path(breakdown))
    end

    it "answers a turbo stream request with a stream" do
      patch judge_breakdown_path(breakdown),
            params: { game_breakdown: { judge_name: "Иванов" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    context "when the attributes are invalid" do
      it "does not update the breakdown" do
        patch judge_breakdown_path(breakdown), params: { game_breakdown: { title: "" } }
        expect(breakdown.reload.title).to be_present
      end

      it "responds with unprocessable content" do
        patch judge_breakdown_path(breakdown), params: { game_breakdown: { title: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        patch judge_breakdown_path(breakdown), params: { game_breakdown: { judge_name: "Иванов" } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /judge/breakdowns/:breakdown_id/seats/:id" do
    let_it_be(:role) { create(:role, code: "sheriff", name: "Шериф") }
    let_it_be(:player) { create(:player, name: "Тестовый") }

    let(:breakdown) { create(:game_breakdown, author: admin) }
    let(:seat) { breakdown.seats.find_by(number: 4) }

    before { sign_in admin }

    it "updates the name" do
      patch judge_breakdown_seat_path(breakdown, seat), params: { breakdown_seat: { name: "Гость" } }
      expect(seat.reload.name).to eq("Гость")
    end

    it "updates the role" do
      patch judge_breakdown_seat_path(breakdown, seat), params: { breakdown_seat: { role_code: "sheriff" } }
      expect(seat.reload.role_code).to eq("sheriff")
    end

    it "links a known player by name" do
      patch judge_breakdown_seat_path(breakdown, seat), params: { breakdown_seat: { name: "Тестовый" } }
      expect(seat.reload.player).to eq(player)
    end

    it "clears the player link when the name no longer matches" do
      seat.update!(name: "Тестовый", player: player)

      patch judge_breakdown_seat_path(breakdown, seat), params: { breakdown_seat: { name: "Некто" } }

      expect(seat.reload.player).to be_nil
    end

    it "redirects back to the editor" do
      patch judge_breakdown_seat_path(breakdown, seat), params: { breakdown_seat: { name: "Гость" } }
      expect(response).to redirect_to(edit_judge_breakdown_path(breakdown))
    end

    it "does not touch a seat of another breakdown" do
      other = create(:game_breakdown, author: admin)

      patch judge_breakdown_seat_path(other, seat), params: { breakdown_seat: { name: "Гость" } }

      expect(response).to have_http_status(:not_found)
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        patch judge_breakdown_seat_path(breakdown, seat), params: { breakdown_seat: { name: "Гость" } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /judge/breakdowns/:breakdown_id/phases" do
    let(:breakdown) { create(:game_breakdown, author: admin) }

    before { sign_in admin }

    it "appends the first night after the zero round" do
      post judge_breakdown_phases_path(breakdown)
      expect(breakdown.phases.reload.map(&:position)).to eq([ 0, 1 ])
    end

    it "redirects back to the editor" do
      post judge_breakdown_phases_path(breakdown)
      expect(response).to redirect_to(edit_judge_breakdown_path(breakdown))
    end

    context "when the next phase is a day" do
      before { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "kill", killed_seat: 7) }

      it "appends the day phase" do
        post judge_breakdown_phases_path(breakdown)
        expect(breakdown.phases.reload.map(&:position)).to eq([ 0, 1, 2 ])
      end

      it "opens the day with the farewell speech of the killed seat" do
        post judge_breakdown_phases_path(breakdown)
        day = breakdown.phases.reload.find_by(position: 2)

        expect(day.speeches.first).to have_attributes(speaker_seat: 7, kind: "farewell", position: 0)
      end

      # The zero round starts at seat 1, so the first day starts at the next alive seat.
      it "creates regular speeches of all alive seats in speech order" do
        post judge_breakdown_phases_path(breakdown)
        day = breakdown.phases.reload.find_by(position: 2)

        expect(day.speeches.where(kind: "regular").map(&:speaker_seat)).to eq([ 2, 3, 4, 5, 6, 8, 9, 10, 1 ])
      end
    end

    context "when the night was a miss" do
      before { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

      it "creates no farewell speech" do
        post judge_breakdown_phases_path(breakdown)
        day = breakdown.phases.reload.find_by(position: 2)

        expect(day.speeches.where(kind: "farewell")).to be_empty
      end

      it "creates regular speeches for all ten seats" do
        post judge_breakdown_phases_path(breakdown)
        day = breakdown.phases.reload.find_by(position: 2)

        expect(day.speeches.map(&:speaker_seat)).to eq([ 2, 3, 4, 5, 6, 7, 8, 9, 10, 1 ])
      end
    end

    context "when the game is already finished" do
      before do
        %w[peace mafia].each { |code| Role.find_or_create_by!(code: code) { |role| role.name = code } }
        breakdown.seats.update_all(role_code: "peace")
      end

      it "does not append a phase" do
        expect { post judge_breakdown_phases_path(breakdown) }.not_to change { breakdown.phases.reload.count }
      end

      it "responds with unprocessable content" do
        post judge_breakdown_phases_path(breakdown)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        post judge_breakdown_phases_path(breakdown)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /judge/breakdowns/:breakdown_id/phases/:id" do
    let(:breakdown) { create(:game_breakdown, author: admin) }
    let!(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

    before { sign_in admin }

    it "deletes the last phase" do
      delete judge_breakdown_phase_path(breakdown, night)
      expect(breakdown.phases.reload.map(&:position)).to eq([ 0 ])
    end

    it "redirects back to the editor" do
      delete judge_breakdown_phase_path(breakdown, night)
      expect(response).to redirect_to(edit_judge_breakdown_path(breakdown))
    end

    it "refuses to delete a phase that is not the last one" do
      zero_round = breakdown.phases.find_by(position: 0)

      delete judge_breakdown_phase_path(breakdown, zero_round)

      expect(breakdown.phases.reload.map(&:position)).to eq([ 0, 1 ])
    end

    it "responds with unprocessable content for a phase that is not the last one" do
      delete judge_breakdown_phase_path(breakdown, breakdown.phases.find_by(position: 0))
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses to delete the zero round when it is the only phase" do
      night.destroy!

      delete judge_breakdown_phase_path(breakdown, breakdown.phases.find_by(position: 0))

      expect(breakdown.phases.reload.count).to eq(1)
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        delete judge_breakdown_phase_path(breakdown, night)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
