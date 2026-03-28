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
        let(:game_params) { { game_number: 99, played_on: "2026-01-15", judge: "Иван", competition_id: competition.id } }

        it "creates a game and redirects" do
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

      context "with valid result" do
        let(:game_params) { { game_number: 97, result: "peace_victory", competition_id: competition.id } }

        it "persists the chosen result" do
          post judge_protocols_path, params: { game: game_params, participations: valid_participations_params }
          expect(Game.last).to be_peace_victory
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

      let(:game_params) { { game_number: 98, played_on: "2026-01-15", judge: "Мария", competition_id: competition.id } }

      it "creates a game and redirects" do
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
        it "updates the game and redirects" do
          patch judge_protocol_path(game), params: {
            game: { game_number: 51, judge: "Новый" },
            participations: valid_participations_params
          }
          expect(response).to redirect_to(game_path(game))
          expect(game.reload.judge).to eq("Новый")
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

      it "updates the game and redirects" do
        patch judge_protocol_path(game), params: {
          game: { game_number: 51, judge: "Новый Ведущий" },
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
