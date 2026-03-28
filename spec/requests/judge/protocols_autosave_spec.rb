require "rails_helper"

RSpec.describe "Judge::Protocols#autosave" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:judge) { create(:user, :judge) }
  let_it_be(:competition) { create(:competition, :series) }
  let_it_be(:role_don) { create(:role, code: "don", name: "Дон") }
  let_it_be(:player) { create(:player, name: "Тестовый") }

  let_it_be(:game) do
    create(:game, game_number: 1, competition: competition, judge: "Судья")
  end

  describe "PATCH /judge/protocols/:id/autosave" do
    context "when user is not signed in" do
      it "redirects to sign in" do
        patch autosave_judge_protocol_path(game), params: {
          scope: "game", field: "judge", value: "Новый"
        }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user is regular user" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "returns not found" do
        patch autosave_judge_protocol_path(game), params: {
          scope: "game", field: "judge", value: "Новый"
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is admin" do
      before { sign_in admin }

      context "with game field updates" do
        it "updates the judge field" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "judge", value: "Новый Ведущий"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body["success"]).to be true
          expect(game.reload.judge).to eq("Новый Ведущий")
        end

        it "updates the game name" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "name", value: "Финал"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(game.reload.name).to eq("Финал")
        end

        it "updates the result" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "result", value: "peace_victory"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(game.reload).to be_peace_victory
        end

        it "updates played_on" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "played_on", value: "2026-03-15"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(game.reload.played_on).to eq(Date.new(2026, 3, 15))
        end

        it "updates competition_id" do
          other_competition = create(:competition, :series)

          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "competition_id", value: other_competition.id
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(game.reload.competition_id).to eq(other_competition.id)
        end

        it "updates game_number" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "game_number", value: "42"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(game.reload.game_number).to eq(42)
        end

        it "rejects disallowed fields" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "id", value: "999"
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["success"]).to be false
        end

        it "returns errors for invalid values" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "result", value: "invalid_result"
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["success"]).to be false
          expect(response.parsed_body["errors"]).to be_present
        end
      end

      context "with participation field updates" do
        it "creates a participation when player_name is set for an empty seat" do
          expect {
            patch autosave_judge_protocol_path(game), params: {
              scope: "participation", seat: 1, field: "player_name", value: "Тестовый"
            }, as: :json
          }.to change(GameParticipation, :count).by(1)

          expect(response).to have_http_status(:ok)
          participation = game.game_participations.find_by(seat: 1)
          expect(participation.player).to eq(player)
        end

        it "creates a new player when name does not match existing" do
          expect {
            patch autosave_judge_protocol_path(game), params: {
              scope: "participation", seat: 2, field: "player_name", value: "Новичок"
            }, as: :json
          }.to change(Player, :count).by(1)

          expect(response).to have_http_status(:ok)
          participation = game.game_participations.find_by(seat: 2)
          expect(participation.player.name).to eq("Новичок")
        end

        it "updates role_code on existing participation" do
          participation = create(:game_participation, game: game, player: player, seat: 3)

          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 3, field: "role_code", value: "don"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(participation.reload.role_code).to eq("don")
        end

        it "updates numeric fields" do
          participation = create(:game_participation, game: game, player: player, seat: 4)

          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 4, field: "plus", value: "1.5"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(participation.reload.plus).to eq(1.5)
        end

        it "rejects win field (removed from form)" do
          participation = create(:game_participation, game: game, player: player, seat: 5)

          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 5, field: "win", value: "1"
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(participation.reload.win).to be false
        end

        it "updates notes" do
          participation = create(:game_participation, game: game, player: player, seat: 6)

          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 6, field: "notes", value: "Хороший ход"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(participation.reload.notes).to eq("Хороший ход")
        end

        it "removes participation when player_name is cleared" do
          create(:game_participation, game: game, player: player, seat: 7)

          expect {
            patch autosave_judge_protocol_path(game), params: {
              scope: "participation", seat: 7, field: "player_name", value: ""
            }, as: :json
          }.to change(GameParticipation, :count).by(-1)

          expect(response).to have_http_status(:ok)
        end

        it "rejects disallowed participation fields" do
          create(:game_participation, game: game, player: player, seat: 8)

          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 8, field: "game_id", value: "999"
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["success"]).to be false
        end

        it "rejects missing seat" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", field: "role_code", value: "don"
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["success"]).to be false
        end

        it "rejects out-of-range seat" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 11, field: "role_code", value: "don"
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["success"]).to be false
        end

        it "returns error for participation update without existing player when field is not player_name" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 9, field: "role_code", value: "don"
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["success"]).to be false
        end
      end

      context "with invalid scope" do
        it "returns error" do
          patch autosave_judge_protocol_path(game), params: {
            scope: "invalid", field: "name", value: "test"
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body["success"]).to be false
        end
      end
    end

    context "when user is judge" do
      before { sign_in judge }

      it "updates the game field" do
        patch autosave_judge_protocol_path(game), params: {
          scope: "game", field: "judge", value: "Мария"
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(game.reload.judge).to eq("Мария")
      end
    end
  end
end
