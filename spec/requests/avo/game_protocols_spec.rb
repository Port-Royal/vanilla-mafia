require "rails_helper"

RSpec.describe "Avo::GameProtocols" do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:role) { create(:role, code: "don", name: "Дон") }
  let_it_be(:player) { create(:player, name: "Тестовый") }

  def valid_participations_params
    params = {}
    params["1"] = { player_name: "Тестовый", role_code: "don", plus: "1", minus: "0", best_move: "", win: "1", first_shoot: "0", notes: "" }
    (2..10).each { |i| params[i.to_s] = { player_name: "", role_code: "", plus: "", minus: "", best_move: "", win: "0", first_shoot: "0", notes: "" } }
    params
  end

  describe "GET /avo/game_protocols/new" do
    context "when user is admin" do
      before do
        sign_in admin
        get new_avo_game_protocol_path
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the new protocol form" do
        expect(response.body).to include(I18n.t("game_protocols.new.title"))
      end
    end

    context "when user is not admin" do
      let(:user) { create(:user, admin: false) }

      before do
        sign_in user
        get new_avo_game_protocol_path
      end

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      before { get new_avo_game_protocol_path }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /avo/game_protocols" do
    before { sign_in admin }

    context "with valid params" do
      let(:game_params) { { season: 5, series: 1, game_number: 99, played_on: "2026-01-15", judge: "Иван" } }

      it "creates a game and redirects" do
        expect {
          post avo_game_protocols_path, params: { game: game_params, participations: valid_participations_params }
        }.to change(Game, :count).by(1)

        expect(response).to redirect_to(%r{/avo/resources/games/\d+})
      end

      it "creates participations for filled seats" do
        expect {
          post avo_game_protocols_path, params: { game: game_params, participations: valid_participations_params }
        }.to change(GameParticipation, :count).by(1)
      end
    end

    context "with invalid game params" do
      let(:invalid_game_params) { { season: "", series: 1, game_number: 1 } }

      it "renders the form with errors" do
        post avo_game_protocols_path, params: { game: invalid_game_params, participations: valid_participations_params }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create a game" do
        expect {
          post avo_game_protocols_path, params: { game: invalid_game_params, participations: valid_participations_params }
        }.not_to change(Game, :count)
      end
    end
  end

  describe "GET /avo/game_protocols/:id/edit" do
    let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 50, judge: "Судья") }
    let_it_be(:participation) { create(:game_participation, game: game, player: player, seat: 1) }

    context "when user is admin" do
      before do
        sign_in admin
        get edit_avo_game_protocol_path(game)
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
  end

  describe "PATCH /avo/game_protocols/:id" do
    let!(:game) { create(:game, season: 5, series: 1, game_number: 51, judge: "Старый") }
    let!(:participation) { create(:game_participation, game: game, player: player, seat: 1) }

    before { sign_in admin }

    context "with valid params" do
      it "updates the game and redirects" do
        patch avo_game_protocol_path(game), params: {
          game: { season: 5, series: 1, game_number: 51, judge: "Новый" },
          participations: valid_participations_params
        }
        expect(response).to redirect_to(%r{/avo/resources/games/\d+})
        expect(game.reload.judge).to eq("Новый")
      end
    end

    context "with invalid game params" do
      it "renders the form with errors" do
        patch avo_game_protocol_path(game), params: {
          game: { season: "", series: 1, game_number: 51 },
          participations: valid_participations_params
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
