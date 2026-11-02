require "rails_helper"

RSpec.describe SyncProtocolEventService do
  let_it_be(:role_don) { create(:role, code: "don") }

  let(:game) { create(:game, hide_roles:) }
  let(:hide_roles) { false }
  let!(:seat_one) { create(:game_participation, game:, seat: 1, role_code: nil) }
  let!(:seat_two) { create(:game_participation, game:, seat: 2, role_code: "don") }
  let(:sent) { [] }
  let(:event) { build(:game_protocol_event, game:, **attrs) }

  before do
    allow(GameProtocolChannel).to receive(:broadcast_to) { |target, payload| sent << [ target, payload ] }
  end

  describe "roles" do
    let(:attrs) { { kind: "roles", phase: "deal", metadata: { "roles" => { "1" => "don" } } } }
    let(:message) { ->(value) { [ game, { scope: "participation", seat: 1, field: "role_code", value: } ] } }

    context "when roles are public" do
      it "writes and broadcasts on apply" do
        described_class.apply(event)

        expect([ seat_one.reload.role_code, sent ]).to eq([ "don", [ message.call("don") ] ])
      end

      it "clears and broadcasts on revert" do
        seat_one.update!(role_code: "don")

        described_class.revert(event)

        expect([ seat_one.reload.role_code, sent ]).to eq([ nil, [ message.call(nil) ] ])
      end
    end

    context "when roles are hidden" do
      let(:hide_roles) { true }

      it "writes without broadcasting on apply" do
        described_class.apply(event)

        expect([ seat_one.reload.role_code, sent ]).to eq([ "don", [] ])
      end

      it "clears without broadcasting on revert" do
        seat_one.update!(role_code: "don")

        described_class.revert(event)

        expect([ seat_one.reload.role_code, sent ]).to eq([ nil, [] ])
      end
    end
  end

  describe "player_left" do
    let(:message) { ->(value) { [ game, { scope: "participation", seat: 2, field: "status", value: } ] } }

    { "killed" => "killed_by_mafia", "voted" => "voted_out", "removed" => "banned" }.each do |reason, status|
      context "when the reason is #{reason}" do
        let(:attrs) { { kind: "player_left", target_seats: [ 2 ], metadata: { "reason" => reason } } }

        it "sets #{status} and broadcasts" do
          described_class.apply(event)

          expect([ seat_two.reload.status, sent ]).to eq([ status, [ message.call(status) ] ])
        end

        it "returns the player on revert" do
          seat_two.update!(status:)

          described_class.revert(event)

          expect([ seat_two.reload.status, sent ]).to eq([ "alive", [ message.call("alive") ] ])
        end
      end
    end

    context "when roles are hidden" do
      let(:hide_roles) { true }
      let(:attrs) { { kind: "player_left", target_seats: [ 2 ], metadata: { "reason" => "killed" } } }

      it "still broadcasts the status" do
        described_class.apply(event)

        expect(sent).to eq([ message.call("killed_by_mafia") ])
      end
    end

    context "when several players leave" do
      let(:attrs) { { kind: "player_left", target_seats: [ 1, 2 ], metadata: { "reason" => "voted" } } }

      it "changes each of them" do
        described_class.apply(event)

        expect([ seat_one, seat_two ].map { |seat| seat.reload.status }).to eq(%w[voted_out voted_out])
      end
    end
  end

  describe "player_restored" do
    let(:attrs) { { kind: "player_restored", target_seats: [ 2 ] } }
    let(:message) { ->(value) { [ game, { scope: "participation", seat: 2, field: "status", value: } ] } }

    it "returns the player on apply" do
      seat_two.update!(status: "banned")

      described_class.apply(event)

      expect([ seat_two.reload.status, sent ]).to eq([ "alive", [ message.call("alive") ] ])
    end

    it "bans again on revert" do
      described_class.revert(event)

      expect([ seat_two.reload.status, sent ]).to eq([ "banned", [ message.call("banned") ] ])
    end
  end

  describe "best_move" do
    let(:attrs) { { kind: "best_move", actor_seat: 1, target_seats: [ 2, 3 ] } }
    let(:message) { ->(value) { [ game, { scope: "participation", seat: 1, field: "best_move_seats", value: } ] } }

    it "writes and broadcasts on apply" do
      described_class.apply(event)

      expect([ seat_one.reload.best_move_seats, sent ]).to eq([ [ 2, 3 ], [ message.call([ 2, 3 ]) ] ])
    end

    context "when the seats are invalid" do
      let(:attrs) { { kind: "best_move", actor_seat: 1, target_seats: [ 1 ] } }

      it "raises" do
        expect { described_class.apply(event) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    it "clears and broadcasts on revert" do
      seat_one.update!(best_move_seats: [ 2, 3 ])

      described_class.revert(event)

      expect([ seat_one.reload.best_move_seats, sent ]).to eq([ nil, [ message.call(nil) ] ])
    end
  end

  describe "game_finished" do
    let(:hide_roles) { true }
    let(:attrs) { { kind: "game_finished", metadata: { "result" => "draw" } } }

    before { allow(BroadcastOverlayRolesService).to receive(:call) }

    it "writes the result" do
      described_class.apply(event)

      expect(game.reload.result).to eq("draw")
    end

    it "reveals the roles" do
      described_class.apply(event)

      expect(BroadcastOverlayRolesService).to have_received(:call).with(game:)
    end

    context "when the result is invalid" do
      let(:attrs) { { kind: "game_finished", metadata: { "result" => "bogus" } } }

      it "raises" do
        expect { described_class.apply(event) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    it "reveals nothing when the transaction rolls back" do
      ActiveRecord::Base.transaction(requires_new: true) do
        described_class.apply(event)
        raise ActiveRecord::Rollback
      end

      expect(BroadcastOverlayRolesService).not_to have_received(:call)
    end

    it "refuses revert" do
      expect { described_class.revert(event) }.to raise_error(described_class::RevertForbidden)
    end
  end

  describe "an event without outcomes" do
    let(:attrs) { { kind: "note" } }

    it "changes and broadcasts nothing on apply" do
      expect { described_class.apply(event) }.not_to(change { [ seat_one.reload.attributes, game.reload.result ] })
      expect(sent).to be_empty
    end

    it "changes and broadcasts nothing on revert" do
      expect { described_class.revert(event) }.not_to(change { seat_one.reload.attributes })
      expect(sent).to be_empty
    end
  end

  describe "an outcome for an empty seat" do
    let(:attrs) { { kind: "player_left", target_seats: [ 7 ], metadata: { "reason" => "killed" } } }

    it "raises" do
      expect { described_class.apply(event) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "a rolled back transaction" do
    let(:attrs) { { kind: "player_left", target_seats: [ 2 ], metadata: { "reason" => "killed" } } }

    it "broadcasts nothing" do
      ActiveRecord::Base.transaction(requires_new: true) do
        described_class.apply(event)
        raise ActiveRecord::Rollback
      end

      expect(sent).to be_empty
    end
  end
end
