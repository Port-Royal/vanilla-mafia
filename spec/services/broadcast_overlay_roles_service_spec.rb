require "rails_helper"

RSpec.describe BroadcastOverlayRolesService do
  let_it_be(:don) { create(:role, code: "don") }
  let_it_be(:game) { create(:game, hide_roles: true) }
  let_it_be(:without_role) { create(:game_participation, game:, seat: 5, role_code: nil) }
  let_it_be(:seated) { create(:game_participation, game:, seat: 1, role_code: "don") }
  let_it_be(:unseated) { create(:game_participation, game:, seat: nil, role_code: "don") }
  let_it_be(:other_game_seat) { create(:game_participation, seat: 7, role_code: "don") }

  let(:sent) do
    messages = []
    allow(GameProtocolChannel).to receive(:broadcast_to) { |target, payload| messages << [ target, payload ] }
    described_class.call(game:)
    messages
  end

  it "lifts the hiding, then sends the role of every seat of this game only" do
    expect(sent).to eq([
      [ game, { scope: "game", field: "hide_roles", value: "0" } ],
      [ game, { scope: "participation", seat: 1, field: "role_code", value: "don" } ],
      [ game, { scope: "participation", seat: 5, field: "role_code", value: nil } ]
    ])
  end
end
