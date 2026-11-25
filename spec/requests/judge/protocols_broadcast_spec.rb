require "rails_helper"

RSpec.describe "GameProtocol broadcasting" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:competition) { create(:competition, :series) }
  let_it_be(:role) { create(:role, code: "don_broadcast", name: "Дон") }
  let_it_be(:player) { create(:player, name: "Тестовый Broadcast") }

  let_it_be(:game) do
    create(:game, game_number: 1, competition: competition, judge: "Судья")
  end

  before { sign_in admin }

  describe "PATCH /judge/protocols/:id/autosave" do
    context "when updating a game field" do
      it "broadcasts the update to the game channel" do
        expect {
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "judge", value: "Новый Ведущий"
          }, as: :json
        }.to have_broadcasted_to(game).from_channel(GameProtocolChannel).with(
          hash_including(
            scope: "game",
            field: "judge",
            value: "Новый Ведущий"
          )
        )
      end
    end

    context "when changing the competition" do
      let_it_be(:other_competition) { create(:competition, :series, name: "Кубок Зимы") }

      it "broadcasts the competition name for the overlay" do
        expect {
          patch autosave_judge_protocol_path(game), params: { scope: "game", field: "competition_id", value: other_competition.id.to_s }, as: :json
        }.to have_broadcasted_to(game).from_channel(GameProtocolChannel).with(
          { scope: "game", field: "competition", value: "Кубок Зимы" }
        )
      end
    end

    context "when picking a stage" do
      let_it_be(:stage) { create(:competition, :round, parent: competition, name: "Финал") }
      let_it_be(:game, reload: true) { create(:game, game_number: 2, competition: competition) }

      it "broadcasts the stage name for the overlay" do
        expect {
          patch autosave_judge_protocol_path(game), params: { scope: "game", field: "stage_id", value: stage.id.to_s }, as: :json
        }.to have_broadcasted_to(game).from_channel(GameProtocolChannel).with(
          { scope: "game", field: "competition", value: "Финал" }
        )
      end
    end

    context "when clearing the stage" do
      let_it_be(:stage) { create(:competition, :round, parent: competition, name: "Финал") }
      let_it_be(:game, reload: true) { create(:game, game_number: 2, competition: stage) }

      it "broadcasts the parent competition name for the overlay" do
        expect {
          patch autosave_judge_protocol_path(game), params: { scope: "game", field: "stage_id", value: competition.id.to_s }, as: :json
        }.to have_broadcasted_to(game).from_channel(GameProtocolChannel).with(
          { scope: "game", field: "competition", value: competition.name }
        )
      end
    end

    context "when switching a display setting" do
      it "broadcasts the update to the game channel" do
        expect {
          patch autosave_judge_protocol_path(game), params: { scope: "game", field: "hide_game_info", value: "1" }, as: :json
        }.to have_broadcasted_to(game).from_channel(GameProtocolChannel).with(
          hash_including(scope: "game", field: "hide_game_info", value: "1")
        )
      end
    end

    context "when updating a participation field" do
      let!(:participation) do
        create(:game_participation, game: game, player: player, seat: 1)
      end

      it "broadcasts the update to the game channel" do
        expect {
          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 1, field: "role_code", value: "don_broadcast"
          }, as: :json
        }.to have_broadcasted_to(game).from_channel(GameProtocolChannel).with(
          hash_including(
            scope: "participation",
            field: "role_code",
            value: "don_broadcast",
            seat: 1
          )
        )
      end
    end

    context "when entering best move seats" do
      let!(:participation) do
        create(:game_participation, game: game, player: player, seat: 1)
      end

      it "broadcasts a participation update with the seats" do
        expect {
          patch autosave_judge_protocol_path(game), params: {
            scope: "participation", seat: 1, field: "best_move_seats", value: [ "3", "7" ]
          }, as: :json
        }.to have_broadcasted_to(game).from_channel(GameProtocolChannel).with(
          hash_including(scope: "participation", field: "best_move_seats", value: [ "3", "7" ], seat: 1)
        )
      end

      it "stores the seats" do
        patch autosave_judge_protocol_path(game), params: {
          scope: "participation", seat: 1, field: "best_move_seats", value: [ "3", "7" ]
        }, as: :json

        expect(participation.reload.best_move_seats).to eq([ 3, 7 ])
      end
    end

    context "when the update fails" do
      it "does not broadcast" do
        expect {
          patch autosave_judge_protocol_path(game), params: {
            scope: "game", field: "result", value: "invalid_result"
          }, as: :json
        }.not_to have_broadcasted_to(game).from_channel(GameProtocolChannel)
      end
    end
  end
end
