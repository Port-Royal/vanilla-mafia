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
