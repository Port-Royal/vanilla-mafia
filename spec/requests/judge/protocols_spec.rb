require "rails_helper"

RSpec.describe "Judge::Protocols" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:judge) { create(:user, :judge) }
  let_it_be(:role) { create(:role, code: "don", name: "Дон") }
  let_it_be(:player) { create(:player, name: "Тестовый") }
  let_it_be(:competition) { create(:competition, :series) }

  def valid_participations_params
    params = {}
    params["1"] = { player_name: "Тестовый", role_code: "don", plus: "1", minus: "0", best_move: "", first_shoot: "0", notes: "" }
    (2..10).each { |i| params[i.to_s] = { player_name: "", role_code: "", plus: "", minus: "", best_move: "", first_shoot: "0", notes: "" } }
    params
  end

  describe "GET /judge/protocols" do
    context "when user is admin" do
      before { sign_in admin }

      it "returns success" do
        get judge_protocols_path
        expect(response).to have_http_status(:ok)
      end

      it "lists in-progress games but not finished ones" do
        in_progress = create(:game, game_number: 77, result: "in_progress", competition: competition)
        finished = create(:game, game_number: 78, result: "peace_victory", competition: competition)

        get judge_protocols_path

        expect(response.body).to include(edit_judge_protocol_path(in_progress))
        expect(response.body).not_to include(edit_judge_protocol_path(finished))
      end

      it "shows edit link for each in-progress game" do
        game = create(:game, game_number: 80, result: "in_progress", competition: competition)
        get judge_protocols_path
        expect(response.body).to include(edit_judge_protocol_path(game))
      end
    end

    context "when user is regular user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "returns not found" do
        get judge_protocols_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get judge_protocols_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /judge/protocols/new" do
    context "when user is admin" do
      before do
        sign_in admin
        get new_judge_protocol_path
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the new protocol form" do
        expect(response.body).to include(I18n.t("game_protocols.new.title"))
      end

      it "pre-fills judge with current user's player nickname" do
        claimed_player = create(:player, name: "AdminNick")
        admin.update!(player: claimed_player)
        get new_judge_protocol_path
        expect(response.body).to include('id="game_judge" value="AdminNick"')
      end

      it "leaves judge blank when user has no claimed player" do
        admin.update!(player: nil)
        get new_judge_protocol_path
        expect(response.body).to include('id="game_judge" value=""')
      end

      it "shows abbreviated label 'ПУ' for first_shoot column" do
        expect(response.body).to include("<th", "ПУ")
        expect(response.body).not_to include("Первый выстрел")
      end

      it "does not show the win column or checkbox" do
        expect(response.body).not_to include('name="participations[1][win]"')
      end

      it "renders result section with same layout as other form rows" do
        expect(response.body).not_to include("<fieldset")
        expect(response.body).not_to include("<legend")
      end

      it "excludes season competitions from the dropdown" do
        season_comp = create(:competition, :season, name: "Season Parent")
        get new_judge_protocol_path
        expect(response.body).not_to include("Season Parent")
        expect(response.body).to include(competition.name)
      end

      it "excludes child competitions from the competition dropdown" do
        create(:competition, :series, parent: competition, name: "Child Series")
        get new_judge_protocol_path
        assert_select "select[name='game[competition_id]'] option", text: "Child Series", count: 0
      end

      it "excludes finished competitions from the dropdown" do
        finished_comp = create(:competition, :series, name: "Finished Series", ended_on: 1.day.ago)
        get new_judge_protocol_path
        expect(response.body).not_to include("Finished Series")
      end

      it "renders the stage selector" do
        assert_select "select[name='game[stage_id]']"
      end

      it "includes child competitions in the stage selector data" do
        create(:competition, :series, parent: competition, name: "Серия 5")
        get new_judge_protocol_path
        expect(response.body).to include("Серия 5")
      end

      it "renders a new stage name input" do
        assert_select "input[name='game[new_stage_name]']"
      end
    end

    context "when user is judge" do
      before do
        sign_in judge
        get new_judge_protocol_path
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the new protocol form" do
        expect(response.body).to include(I18n.t("game_protocols.new.title"))
      end
    end

    context "when user is regular user" do
      let(:user) { create(:user) }

      before do
        sign_in user
        get new_judge_protocol_path
      end

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      before { get new_judge_protocol_path }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /judge/protocols" do
    context "when user is admin" do
      before { sign_in admin }

      context "with valid params" do
        let(:game_params) { { game_number: 99, played_on: "2026-01-15", judge: "Иван", result: "peace_victory", competition_id: competition.id } }

        it "creates a game and redirects to show" do
          expect {
            post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          }.to change(Game, :count).by(1)

          expect(response).to redirect_to(game_path(Game.last))
        end

        it "creates participations for filled seats" do
          expect {
            post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          }.to change(GameParticipation, :count).by(1)
        end
      end

      context "with existing stage" do
        let_it_be(:stage) { create(:competition, :series, parent: competition, name: "Серия 3") }
        let(:game_params) { { game_number: 96, result: "peace_victory", competition_id: competition.id, stage_id: stage.id } }

        it "sets the game competition to the selected stage" do
          post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          expect(Game.last.competition).to eq(stage)
        end
      end

      context "with new stage name" do
        let(:game_params) { { game_number: 94, result: "peace_victory", competition_id: competition.id, new_stage_name: "Серия 7" } }

        it "creates a new child competition" do
          expect {
            post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          }.to change(Competition, :count).by(1)
        end

        it "sets the game competition to the new stage" do
          post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          expect(Game.last.competition.name).to eq("Серия 7")
          expect(Game.last.competition.parent).to eq(competition)
        end
      end

      context "with valid result" do
        let(:game_params) { { game_number: 97, result: "peace_victory", competition_id: competition.id } }

        it "persists the chosen result" do
          post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          expect(Game.last).to be_peace_victory
        end
      end

      context "with in_progress result" do
        let(:game_params) { { game_number: 95, result: "in_progress", competition_id: competition.id } }

        it "redirects to edit instead of show" do
          post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          expect(response).to redirect_to(edit_judge_protocol_path(Game.last))
        end
      end

      context "with invalid result" do
        let(:game_params) { { game_number: 96, result: "invalid", competition_id: competition.id } }

        it "rejects the invalid result" do
          expect {
            post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          }.not_to change(Game, :count)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "with invalid game params" do
        let(:invalid_game_params) { { game_number: 1 } }

        it "renders the form with errors" do
          post judge_protocols_path, params: { game: invalid_game_params, participations: valid_participations_params }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not create a game" do
          expect {
            post judge_protocols_path, params: { game: invalid_game_params, participations: valid_participations_params }
          }.not_to change(Game, :count)
        end

        it "preserves submitted player name in the re-rendered form" do
          post judge_protocols_path, params: { game: invalid_game_params, participations: valid_participations_params }
          expect(response.body).to include("Тестовый")
        end

        it "preserves submitted player name for new players" do
          params_with_new_player = valid_participations_params.merge(
            "2" => { player_name: "Совсем Новый", role_code: "don", plus: "1", minus: "0", best_move: "", first_shoot: "0", notes: "" }
          )
          post judge_protocols_path, params: { game: invalid_game_params, participations: params_with_new_player }
          expect(response.body).to include("Совсем Новый")
        end
      end
    end

    context "when user is judge" do
      before { sign_in judge }

      let(:game_params) { { game_number: 98, played_on: "2026-01-15", judge: "Мария", result: "mafia_victory", competition_id: competition.id } }

      it "creates a game and redirects to show" do
        expect {
          post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
        }.to change(Game, :count).by(1)

        expect(response).to redirect_to(game_path(Game.last))
      end
    end

    context "when user is regular user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "returns not found" do
        post judge_protocols_path, params: { game: { game_number: 1 }, participations: valid_participations_params }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        post judge_protocols_path, params: { game: { game_number: 1 }, participations: valid_participations_params }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /judge/protocols/:id/edit" do
    let_it_be(:game) { create(:game, game_number: 50, judge: "Судья") }
    let_it_be(:participation) { create(:game_participation, game: game, player: player, seat: 1) }

    context "when user is admin" do
      before do
        sign_in admin
        get edit_judge_protocol_path(game)
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the edit form with game data" do
        expect(response.body).to include(I18n.t("game_protocols.edit.title"))
      end

      it "pre-fills the player name" do
        expect(response.body).to include("Тестовый")
      end
    end

    context "when user is judge" do
      before do
        sign_in judge
        get edit_judge_protocol_path(game)
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the edit form with game data" do
        expect(response.body).to include(I18n.t("game_protocols.edit.title"))
      end
    end

    context "when game has legacy participations without seats" do
      let!(:legacy_game) { create(:game, game_number: 50) }
      let!(:legacy_participation) { create(:game_participation, game: legacy_game, player: player, seat: nil) }

      before do
        sign_in admin
        get edit_judge_protocol_path(legacy_game)
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "shows the legacy player in the form" do
        expect(response.body).to include("Тестовый")
      end
    end

    context "when user is regular user" do
      let(:user) { create(:user) }

      before do
        sign_in user
        get edit_judge_protocol_path(game)
      end

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      before { get edit_judge_protocol_path(game) }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /judge/protocols/:id" do
    let!(:game) { create(:game, game_number: 51, judge: "Старый") }
    let!(:participation) { create(:game_participation, game: game, player: player, seat: 1) }

    context "when user is admin" do
      before { sign_in admin }

      context "with valid params" do
        it "updates the game and redirects to show when finished" do
          patch judge_protocol_path(game), params: {
            game: { game_number: 51, judge: "Новый", result: "peace_victory" },
            participations: valid_participations_params
          }
          expect(response).to redirect_to(game_path(game))
          expect(game.reload.judge).to eq("Новый")
        end
      end

      context "with in_progress result" do
        it "redirects to edit instead of show" do
          patch judge_protocol_path(game), params: {
            game: { game_number: 51, result: "in_progress" },
            participations: valid_participations_params
          }
          expect(response).to redirect_to(edit_judge_protocol_path(game))
        end
      end

      context "with invalid game params" do
        it "renders the form with errors" do
          patch judge_protocol_path(game), params: {
            game: { game_number: nil, competition_id: competition.id },
            participations: valid_participations_params
          }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when user is judge" do
      before { sign_in judge }

      it "updates the game and redirects to show when finished" do
        patch judge_protocol_path(game), params: {
          game: { game_number: 51, judge: "Новый Ведущий", result: "mafia_victory" },
          participations: valid_participations_params
        }
        expect(response).to redirect_to(game_path(game))
        expect(game.reload.judge).to eq("Новый Ведущий")
      end
    end

    context "when user is regular user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "returns not found" do
        patch judge_protocol_path(game), params: {
          game: { game_number: 51 },
          participations: valid_participations_params
        }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        patch judge_protocol_path(game), params: {
          game: { game_number: 51 },
          participations: valid_participations_params
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
