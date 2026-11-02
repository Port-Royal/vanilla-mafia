require "rails_helper"

RSpec.describe "Judge::Protocols role visibility broadcasts" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:role_don) { create(:role, code: "don", name: "Дон") }
  let_it_be(:role_peace) { create(:role, code: "peace", name: "Мирный") }

  let(:game) { create(:game, hide_roles:) }
  let!(:participation) { create(:game_participation, game:, seat: 3, role_code: "peace") }
  let(:sent) { [] }
  let(:role_message) { { scope: "participation", seat: 3, field: "role_code", value: "don" } }
  let(:autosave) { ->(attrs) { patch autosave_judge_protocol_path(game), params: attrs, as: :json } }

  before do
    sign_in admin
    allow(GameProtocolChannel).to receive(:broadcast_to) { |_target, payload| sent << payload.to_h.symbolize_keys }
  end

  context "when roles are hidden in a running game" do
    let(:hide_roles) { true }

    context "when the judge changes a role" do
      before { autosave.call(scope: "participation", seat: 3, field: "role_code", value: "don") }

      it "saves the role" do
        expect(participation.reload.role_code).to eq("don")
      end

      it "broadcasts nothing" do
        expect(sent).to be_empty
      end
    end

    context "when the judge changes another participation field" do
      before { autosave.call(scope: "participation", seat: 3, field: "status", value: "voted_out") }

      it "still broadcasts it" do
        expect(sent).to eq([ { scope: "participation", field: "status", value: "voted_out", seat: 3 } ])
      end
    end

    context "when the judge switches hiding off" do
      before do
        create(:game_protocol_event, game:, kind: "sheriff_check", phase: "night", day_number: 0, target_seats: [ 3 ], metadata: { "result" => "red" })
        autosave.call(scope: "game", field: "hide_roles", value: "0")
      end

      it "sends the roles after the setting" do
        expect(sent).to include({ scope: "participation", seat: 3, field: "role_code", value: "peace" })
      end

      it "sends the checks gathered so far" do
        expect(sent.last).to eq(scope: "checks", checks: [ { night: 1, kind: "sheriff", target_seat: 3, result: "red" } ])
      end
    end

    context "when the game finishes through autosave" do
      before { autosave.call(scope: "game", field: "result", value: "draw") }

      it "sends the roles" do
        expect(sent).to include(scope: "participation", seat: 3, field: "role_code", value: "peace")
      end
    end

    context "when an autosave is rejected" do
      before { autosave.call(scope: "game", field: "result", value: "invalid") }

      it "sends nothing" do
        expect(sent).to be_empty
      end
    end

    context "when the game finishes through the form" do
      before do
        patch judge_protocol_path(game), params: {
          game: { game_number: game.game_number, competition_id: game.competition_id, result: "draw" },
          participations: { "3" => { player_name: participation.player.name, role_code: "peace" } }
        }
      end

      it "sends the roles" do
        expect(sent).to include(scope: "participation", seat: 3, field: "role_code", value: "peace")
      end
    end

    context "when the form saves without revealing" do
      before do
        patch judge_protocol_path(game), params: {
          game: { game_number: game.game_number, competition_id: game.competition_id },
          participations: { "3" => { player_name: participation.player.name, role_code: "don" } }
        }
      end

      it "sends nothing" do
        expect(sent).to be_empty
      end
    end
  end

  context "when roles are public" do
    let(:hide_roles) { false }

    context "when the judge changes a role" do
      before { autosave.call(scope: "participation", seat: 3, field: "role_code", value: "don") }

      it "broadcasts it once" do
        expect(sent).to eq([ role_message ])
      end
    end

    context "when the form saves" do
      before do
        patch judge_protocol_path(game), params: {
          game: { game_number: game.game_number, competition_id: game.competition_id },
          participations: { "3" => { player_name: participation.player.name, role_code: "don" } }
        }
      end

      it "sends nothing" do
        expect(sent).to be_empty
      end
    end

    context "when the judge switches hiding on" do
      before { autosave.call(scope: "game", field: "hide_roles", value: "1") }

      it "sends the setting and empties the checks" do
        expect(sent).to eq([ { scope: "game", field: "hide_roles", value: "1" }, { scope: "checks", checks: [] } ])
      end
    end

    context "when a finished game is reopened with hiding on" do
      let(:game) { create(:game, hide_roles: true, result: "draw") }

      before { autosave.call(scope: "game", field: "result", value: "in_progress") }

      it "tells the overlay to hide roles" do
        expect(sent).to include({ scope: "game", field: "hide_roles", value: "1" })
      end

      it "addresses the message to this game" do
        expect(GameProtocolChannel).to have_received(:broadcast_to).with(game, { scope: "checks", checks: [] })
      end
    end
  end
end
