require "rails_helper"

RSpec.describe "Judge live protocol" do
  let_it_be(:judge) { create(:user, :judge) }
  let_it_be(:user) { create(:user) }

  let!(:toggle) { create(:feature_toggle, key: "live_protocol", enabled: true) }
  let(:game) { create(:game) }
  let!(:seat_two) { create(:game_participation, game:, seat: 2, role_code: nil) }
  let(:current_user) { judge }
  let(:event) { { client_id: "c1", action_id: "a1", kind: "note", phase: "day", day_number: 1, text: "hello" } }
  let(:post_events) { ->(*events) { post live_events_judge_protocol_path(game), params: { events: }, as: :json } }
  let(:journal) { game.game_protocol_events.order(:position) }

  before { sign_in current_user }

  describe "GET /judge/protocols/:id/live" do
    let!(:saved) { create(:game_protocol_event, game:, client_id: "saved") }

    before { get live_judge_protocol_path(game) }

    it "returns success" do
      expect(response).to have_http_status(:ok)
    end

    it "hands over the players" do
      node = css_select("#live-protocol").first
      expect(JSON.parse(node["data-live-protocol-players-value"]))
        .to eq([ { "seat" => 2, "name" => seat_two.player.name, "role_code" => nil, "status" => "alive" } ])
    end

    it "hands over the events" do
      node = css_select("#live-protocol").first
      expect(JSON.parse(node["data-live-protocol-events-value"]).map { |row| row["client_id"] }).to eq([ "saved" ])
    end
  end

  describe "GET /judge/protocols/:id/live with seats and events out of order" do
    let(:players) { JSON.parse(css_select("#live-protocol").first["data-live-protocol-players-value"]) }
    let(:events) { JSON.parse(css_select("#live-protocol").first["data-live-protocol-events-value"]) }

    before do
      create(:role, code: "don")
      create(:game_participation, game:, seat: 1, role_code: "don")
      create(:game_participation, game:, seat: nil, role_code: "don")
      create(:game_protocol_event, game:, client_id: "later", position: 2)
      create(:game_protocol_event, game:, client_id: "earlier", position: 1)
      get live_judge_protocol_path(game)
    end

    it "lists only seated players, by seat" do
      expect(players.pluck("seat")).to eq([ 1, 2 ])
    end

    it "hands the judge the roles" do
      expect(players.first["role_code"]).to eq("don")
    end

    it "lists events by position" do
      expect(events.pluck("client_id")).to eq(%w[earlier later])
    end
  end

  describe "an unknown game" do
    before { get live_judge_protocol_path("no-such-game") }

    it "answers 404" do
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /judge/protocols/:id/live/events" do
    context "when a retry was waiting for the lock" do
      let(:left) { event.merge(kind: "player_left", target_seats: [ 2 ], metadata: { reason: "killed" }) }

      before do
        allow_any_instance_of(Game).to receive(:with_lock).and_wrap_original do |original, &block|
          create(:game_protocol_event, game:, client_id: "c1", position: 1)
          original.call(&block)
        end
        post_events.call(left)
      end

      it "answers saved" do
        expect(response.parsed_body).to eq("saved" => [ "c1" ])
      end

      it "does not apply the outcome again" do
        expect(seat_two.reload.status).to eq("alive")
      end
    end

    context "when the game finished while the request waited for the lock" do
      before do
        allow_any_instance_of(Game).to receive(:with_lock).and_wrap_original do |original, &block|
          Game.where(id: game.id).update_all(result: "draw")
          original.call(&block)
        end
        post_events.call(event)
      end

      it "answers 409" do
        expect(response).to have_http_status(:conflict)
      end

      it "saves nothing" do
        expect(journal.count).to eq(0)
      end
    end

    context "with new events" do
      before do
        post_events.call(event, event.merge(client_id: "c2", kind: "foul", actor_seat: 2, target_seats: [ 2 ], metadata: { x: [ 1 ] }))
      end

      it "answers with what is saved" do
        expect(response.parsed_body).to eq("saved" => %w[c1 c2])
      end

      it "keeps the order they were sent in" do
        expect(journal.map { |row| [ row.client_id, row.position ] }).to eq([ [ "c1", 1 ], [ "c2", 2 ] ])
      end

      it "stores every field" do
        expect(journal.last).to have_attributes(
          action_id: "a1", kind: "foul", phase: "day", day_number: 1, actor_seat: 2,
          target_seats: [ 2 ], text: "hello", metadata: { "x" => [ 1 ] }
        )
      end

      it "continues the positions on the next request" do
        post_events.call(event.merge(client_id: "c3"))

        expect(journal.last.position).to eq(3)
      end
    end

    context "when the same client_id is sent again" do
      before do
        2.times { post_events.call(event) }
      end

      it "creates one record" do
        expect(journal.count).to eq(1)
      end

      it "still answers saved" do
        expect(response.parsed_body).to eq("saved" => [ "c1" ])
      end
    end

    context "when a client_id repeats inside one request" do
      before { post_events.call(event, event.merge(text: "retried")) }

      it "creates one record" do
        expect(journal.map(&:text)).to eq([ "hello" ])
      end

      it "names it once" do
        expect(response.parsed_body).to eq("saved" => [ "c1" ])
      end
    end

    context "when the same client_id exists in another game" do
      before do
        create(:game_protocol_event, client_id: "c1")
        post_events.call(event)
      end

      it "saves the event" do
        expect(journal.count).to eq(1)
      end
    end

    context "when an event has an outcome" do
      before { post_events.call(event.merge(kind: "player_left", target_seats: [ 2 ], metadata: { reason: "killed" })) }

      it "applies it" do
        expect(seat_two.reload.status).to eq("killed_by_mafia")
      end
    end

    context "when a retried event has an outcome" do
      let(:left) { event.merge(kind: "player_left", target_seats: [ 2 ], metadata: { reason: "killed" }) }

      before do
        post_events.call(left)
        seat_two.reload.update!(status: "alive")
        post_events.call(left)
      end

      it "does not apply it twice" do
        expect(seat_two.reload.status).to eq("alive")
      end
    end

    context "when one event of the batch is invalid" do
      before { post_events.call(event, event.merge(client_id: "c2", kind: "bogus")) }

      it "answers 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "reports the errors" do
        expect(response.parsed_body["errors"]).to be_present
      end

      it "saves nothing" do
        expect(journal.count).to eq(0)
      end
    end

    context "when an outcome names an empty seat" do
      before { post_events.call(event, event.merge(client_id: "c2", kind: "player_left", target_seats: [ 7 ], metadata: { reason: "killed" })) }

      it "answers 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "saves nothing" do
        expect(journal.count).to eq(0)
      end
    end

    context "when roles name an unknown role" do
      before { post_events.call(event.merge(kind: "roles", phase: "deal", metadata: { roles: { "2" => "nobody" } })) }

      it "answers 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when no events are sent" do
      before { post live_events_judge_protocol_path(game), params: {}, as: :json }

      it "saves nothing and answers an empty list" do
        expect(response.parsed_body).to eq("saved" => [])
      end
    end

    context "when the game is not in progress" do
      let(:game) { create(:game, result: "draw") }

      before { post_events.call(event) }

      it "answers 409" do
        expect(response).to have_http_status(:conflict)
      end

      it "saves nothing" do
        expect(journal.count).to eq(0)
      end
    end

    context "when the response to the finishing request was lost" do
      let(:finish) { event.merge(kind: "game_finished", metadata: { result: "draw" }) }

      before { 2.times { post_events.call(finish) } }

      it "answers saved to the retry" do
        expect(response.parsed_body).to eq("saved" => [ "c1" ])
      end
    end
  end

  describe "nominee broadcasts" do
    let(:sent) { [] }
    let(:nomination) { event.merge(kind: "nominate", actor_seat: 1, target_seats: [ 2 ]) }

    before do
      allow(GameProtocolChannel).to receive(:broadcast_to) { |_game, payload| sent << payload }
    end

    it "sends the list after a nomination" do
      post_events.call(nomination)

      expect(sent).to eq([ { scope: "nominees", seats: [ 2 ] } ])
    end

    it "addresses the list to this game" do
      post_events.call(nomination)

      expect(GameProtocolChannel).to have_received(:broadcast_to).with(game, { scope: "nominees", seats: [ 2 ] })
    end

    it "sends nothing when the list stays the same" do
      post_events.call(event)

      expect(sent).to be_empty
    end

    it "sends the list after its deletion" do
      post_events.call(nomination)
      delete live_event_judge_protocol_path(game, "a1"), as: :json

      expect(sent.last).to eq(scope: "nominees", seats: [])
    end

    it "sends nothing for a retried request" do
      post_events.call(nomination)
      post_events.call(nomination)

      expect(sent.size).to eq(1)
    end

    it "sends nothing for a rejected batch" do
      post_events.call(nomination, event.merge(client_id: "c2", kind: "bogus"))

      expect(sent).to be_empty
    end
  end

  describe "shot broadcasts" do
    let(:sent) { [] }
    let(:shot) { event.merge(kind: "shot", phase: "night", day_number: 0, target_seats: [ 2 ]) }

    before do
      allow(GameProtocolChannel).to receive(:broadcast_to) { |target, payload| sent << [ target, payload ] }
    end

    it "sends the shots after a shot" do
      post_events.call(shot)

      expect(sent).to eq([ [ game, { scope: "shots", shots: [ { night: 1, target_seat: 2, team: nil } ] } ] ])
    end

    context "when roles are hidden" do
      let(:game) { create(:game, hide_roles: true) }

      it "still sends them" do
        post_events.call(shot)

        expect(sent.map(&:last)).to eq([ { scope: "shots", shots: [ { night: 1, target_seat: 2, team: nil } ] } ])
      end
    end
  end

  describe "check broadcasts" do
    let(:sent) { [] }
    let(:check) { event.merge(kind: "don_check", phase: "night", day_number: 0, actor_seat: 1, target_seats: [ 2 ], metadata: { result: "not_sheriff" }) }
    let(:public_check) { { scope: "checks", checks: [ { night: 1, kind: "don", target_seat: 2, result: "not_sheriff", team: nil } ] } }

    before do
      allow(GameProtocolChannel).to receive(:broadcast_to) { |target, payload| sent << [ target, payload ] }
    end

    context "when roles are public" do
      it "sends the checks after a check" do
        post_events.call(check)

        expect(sent).to eq([ [ game, public_check ] ])
      end

      it "sends the list without it after an undo" do
        post_events.call(check)
        delete live_event_judge_protocol_path(game, "a1"), as: :json

        expect(sent.last).to eq([ game, { scope: "checks", checks: [] } ])
      end
    end

    context "when roles are hidden" do
      let(:game) { create(:game, hide_roles: true) }

      it "sends nothing" do
        post_events.call(check)

        expect(sent).to be_empty
      end
    end
  end

  describe "DELETE /judge/protocols/:id/live/events/:action_id" do
    let(:delete_action) { ->(action_id) { delete live_event_judge_protocol_path(game, action_id), as: :json } }

    context "with the last action" do
      let!(:other) { create(:game_protocol_event, game:, action_id: "keep", position: 1) }
      let!(:foreign) { create(:game_protocol_event, action_id: "undo", position: 9) }

      before do
        create(:game_protocol_event, game:, action_id: "undo", position: 2, kind: "foul")
        create(:game_protocol_event, game:, action_id: "undo", position: 3, kind: "tech")
        delete_action.call("undo")
      end

      it "answers no content" do
        expect(response).to have_http_status(:no_content)
      end

      it "removes the whole group of this game only" do
        expect(GameProtocolEvent.where(id: [ other.id, foreign.id ]).count).to eq(2)
        expect(journal.to_a).to eq([ other ])
      end
    end

    context "with roles confirmed from the form" do
      let!(:role_don) { create(:role, code: "don") }
      let(:roles) { event.merge(kind: "roles", phase: "deal", metadata: { roles: { "2" => "don" }, previous_roles: { "2" => "don" } }) }

      before { seat_two.update!(role_code: "don") }

      it "keeps the form's role through confirm and undo" do
        post_events.call(roles)
        delete_action.call("a1")

        expect(seat_two.reload.role_code).to eq("don")
      end
    end

    context "with a group that has outcomes" do
      let(:left) { event.merge(kind: "player_left", target_seats: [ 2 ], metadata: { reason: "voted" }) }

      it "brings the status back through the whole cycle" do
        post_events.call(left)
        statuses = [ seat_two.reload.status ]
        delete_action.call("a1")

        expect(statuses << seat_two.reload.status).to eq(%w[voted_out alive])
      end

      it "reverts newest first" do
        post_events.call(
          event.merge(kind: "player_left", target_seats: [ 2 ], metadata: { reason: "removed" }),
          event.merge(client_id: "c2", kind: "player_restored", target_seats: [ 2 ])
        )
        delete_action.call("a1")

        expect(seat_two.reload.status).to eq("alive")
      end
    end

    context "when a repeated delete was waiting for the lock" do
      before do
        create(:game_protocol_event, game:, action_id: "a1", kind: "player_left", target_seats: [ 2 ], metadata: { "reason" => "voted" })
        allow_any_instance_of(Game).to receive(:with_lock).and_wrap_original do |original, &block|
          GameProtocolEvent.where(action_id: "a1").delete_all
          seat_two.update!(status: "banned")
          original.call(&block)
        end
        delete_action.call("a1")
      end

      it "answers no content" do
        expect(response).to have_http_status(:no_content)
      end

      it "does not revert again" do
        expect(seat_two.reload.status).to eq("banned")
      end
    end

    context "when rows of a group were written out of position order" do
      before do
        seat_two.update!(status: "alive")
        create(:game_protocol_event, game:, action_id: "a1", position: 2, kind: "player_restored", target_seats: [ 2 ])
        create(:game_protocol_event, game:, action_id: "a1", position: 1, kind: "player_left", target_seats: [ 2 ], metadata: { "reason" => "removed" })
        delete_action.call("a1")
      end

      it "still reverts by position, newest first" do
        expect(seat_two.reload.status).to eq("alive")
      end
    end

    context "when a revert fails halfway through a group" do
      before do
        seat_two.update!(status: "voted_out")
        create(:game_protocol_event, game:, action_id: "a1", position: 1, kind: "game_finished", metadata: { "result" => "draw" })
        create(:game_protocol_event, game:, action_id: "a1", position: 2, kind: "player_left", target_seats: [ 2 ], metadata: { "reason" => "voted" })
        delete_action.call("a1")
      end

      it "rolls the status back" do
        expect(seat_two.reload.status).to eq("voted_out")
      end

      it "keeps every event" do
        expect(journal.count).to eq(2)
      end
    end

    context "with a middle action that may not be deleted" do
      before do
        create(:game_protocol_event, game:, action_id: "mid", position: 1, kind: "foul")
        create(:game_protocol_event, game:, action_id: "end", position: 2)
        delete_action.call("mid")
      end

      it "explains the refusal" do
        expect(response.parsed_body["errors"]).to eq([ "action cannot be deleted" ])
      end

      it "answers 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "keeps the events" do
        expect(journal.count).to eq(2)
      end
    end

    context "with a middle action that may be deleted" do
      before do
        create(:game_protocol_event, game:, action_id: "mid", position: 1, kind: "note")
        create(:game_protocol_event, game:, action_id: "end", position: 2)
        delete_action.call("mid")
      end

      it "removes it and keeps the others" do
        expect(journal.map(&:action_id)).to eq([ "end" ])
      end
    end

    context "when the action is already gone" do
      before { delete_action.call("missing") }

      it "answers no content for a retry" do
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when the game is not in progress" do
      let(:game) { create(:game, result: "draw") }

      before do
        create(:game_protocol_event, game:, action_id: "a1")
        delete_action.call("a1")
      end

      it "answers 409" do
        expect(response).to have_http_status(:conflict)
      end

      it "keeps the event" do
        expect(journal.count).to eq(1)
      end
    end

    context "when a reopened game asks to undo its finish" do
      before do
        create(:game_protocol_event, game:, action_id: "a1", kind: "game_finished", metadata: { "result" => "draw" })
        delete_action.call("a1")
      end

      it "answers 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "keeps the event" do
        expect(journal.count).to eq(1)
      end
    end
  end

  [
    [ "without access", -> { sign_in user } ],
    [ "with the flag off", -> { toggle.update!(enabled: false) } ]
  ].each do |name, setup|
    context "when #{name}" do
      before { instance_exec(&setup) }

      it "hides the page" do
        get live_judge_protocol_path(game)

        expect(response).to have_http_status(:not_found)
      end

      it "refuses to create" do
        post_events.call(event)

        expect([ response.status, journal.count ]).to eq([ 404, 0 ])
      end

      it "refuses to delete" do
        create(:game_protocol_event, game:, action_id: "a1")
        delete live_event_judge_protocol_path(game, "a1"), as: :json

        expect([ response.status, journal.count ]).to eq([ 404, 1 ])
      end
    end
  end
end
