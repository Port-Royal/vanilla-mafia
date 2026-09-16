require "rails_helper"

RSpec.describe "Judge::Breakdowns day editing" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:breakdown) { create(:game_breakdown, author: admin) }
  let(:zero_round) { breakdown.phases.find_by(position: 0) }

  before { sign_in admin }

  describe "GET /judge/breakdowns/:id/edit" do
    let!(:first_speech) { speech(zero_round, 1) }
    let!(:move) { create(:breakdown_move, :nomination, breakdown_speech: first_speech, actor_seat: 1, target_seat: 4) }

    it "returns success" do
      get edit_judge_breakdown_path(breakdown)
      expect(response).to have_http_status(:ok)
    end

    it "renders the speech block" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include(%(id="#{ActionView::RecordIdentifier.dom_id(first_speech)}"))
    end

    it "renders the move summary" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include(I18n.t("game_breakdowns.move_kinds.nomination"))
    end

    it "offers the add-move form" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include(I18n.t("game_breakdowns.editor.add_move"))
    end

    it "offers the add-speech form" do
      get edit_judge_breakdown_path(breakdown)
      expect(response.body).to include(I18n.t("game_breakdowns.editor.add_speech"))
    end

    context "when a vote round exists" do
      let!(:second_nomination) { nominate(zero_round, 2, 5) }
      let!(:round) { vote(zero_round, "main", [ 1, 2, 3, 4, 5, 6 ] => 4, [ 7, 8, 9, 10 ] => 5) }

      it "renders the round block" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body).to include(%(id="#{ActionView::RecordIdentifier.dom_id(round)}"))
      end

      it "renders the round outcome" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body).to include(I18n.t("game_breakdowns.vote_outcomes.eliminated"))
      end

      it "renders a vote row for every alive voter" do
        get edit_judge_breakdown_path(breakdown)
        expect(response.body.scan(/name="votes\[\d+\]\[candidate_seat\]"/).size).to eq(10)
      end
    end
  end

  describe "POST /judge/breakdowns/:breakdown_id/speeches" do
    let(:params) { { breakdown_phase_id: zero_round.id, breakdown_speech: { speaker_seat: 6, kind: "regular" } } }

    it "creates the speech" do
      expect { post judge_breakdown_speeches_path(breakdown), params: params }.to change { zero_round.speeches.reload.count }.by(1)
    end

    it "stores the submitted speaker and kind" do
      post judge_breakdown_speeches_path(breakdown), params: params
      expect(zero_round.speeches.reload.last).to have_attributes(speaker_seat: 6, kind: "regular")
    end

    it "appends it after the existing speeches" do
      speech(zero_round, 1)

      post judge_breakdown_speeches_path(breakdown), params: params

      expect(zero_round.speeches.reload.last.speaker_seat).to eq(6)
    end

    it "refuses to create a justification speech by hand" do
      post judge_breakdown_speeches_path(breakdown),
           params: { breakdown_phase_id: zero_round.id, breakdown_speech: { speaker_seat: 6, kind: "justification" } }

      expect(zero_round.speeches.reload.last.kind).to eq("regular")
    end

    it "redirects back to the editor" do
      post judge_breakdown_speeches_path(breakdown), params: params
      expect(response).to redirect_to(edit_judge_breakdown_path(breakdown))
    end

    context "when the toggle is off" do
      before { toggle.update!(enabled: false) }

      it "returns not found" do
        post judge_breakdown_speeches_path(breakdown), params: params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the user is a regular user" do
      before { sign_in user }

      it "returns not found" do
        post judge_breakdown_speeches_path(breakdown), params: params
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /judge/breakdowns/:breakdown_id/speeches/:id" do
    let!(:target) { speech(zero_round, 3) }

    it "deletes the speech" do
      expect { delete judge_breakdown_speech_path(breakdown, target) }.to change { zero_round.speeches.reload.count }.by(-1)
    end

    it "deletes its moves with it" do
      create(:breakdown_move, :nomination, breakdown_speech: target, actor_seat: 3, target_seat: 5)

      delete judge_breakdown_speech_path(breakdown, target)

      expect(BreakdownMove.count).to eq(0)
    end

    it "does not reach a speech of another breakdown" do
      other = create(:game_breakdown, author: admin)

      delete judge_breakdown_speech_path(other, target)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /judge/breakdowns/:breakdown_id/moves" do
    let!(:host_speech) { speech(zero_round, 2) }
    let(:params) do
      { speech_id: host_speech.id, breakdown_move: { kind: "nomination", actor_seat: 2, target_seat: 7 } }
    end

    it "creates the move" do
      expect { post judge_breakdown_moves_path(breakdown), params: params }.to change { host_speech.moves.reload.count }.by(1)
    end

    it "stores the submitted attributes" do
      post judge_breakdown_moves_path(breakdown), params: params
      expect(host_speech.moves.reload.last).to have_attributes(kind: "nomination", actor_seat: 2, target_seat: 7)
    end

    it "numbers moves from zero within the speech" do
      post judge_breakdown_moves_path(breakdown), params: params
      post judge_breakdown_moves_path(breakdown), params: params

      expect(host_speech.moves.reload.map(&:position)).to eq([ 0, 1 ])
    end

    it "attaches a move to a vote round when asked" do
      round = vote(zero_round, "main")

      post judge_breakdown_moves_path(breakdown),
           params: { vote_round_id: round.id, breakdown_move: { kind: "other", actor_seat: 3, text: "снял руку" } }

      expect(round.moves.reload.map(&:text)).to eq([ "снял руку" ])
    end

    it "keeps a best move as an array of seats" do
      post judge_breakdown_moves_path(breakdown),
           params: { speech_id: host_speech.id,
                     breakdown_move: { kind: "best_move", actor_seat: 2, best_move_seats: [ "3", "", "9" ] } }

      expect(host_speech.moves.reload.last.best_move_seats).to eq([ 3, 9 ])
    end

    context "when a required field for the kind is missing" do
      it "creates nothing" do
        expect {
          post judge_breakdown_moves_path(breakdown), params: { speech_id: host_speech.id, breakdown_move: { kind: "nomination", actor_seat: 2 } }
        }.not_to change(BreakdownMove, :count)
      end

      it "responds with unprocessable content" do
        post judge_breakdown_moves_path(breakdown), params: { speech_id: host_speech.id, breakdown_move: { kind: "nomination", actor_seat: 2 } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when nominations open a vote" do
      before { nominate(zero_round, 1, 4) }

      it "creates the main round automatically" do
        post judge_breakdown_moves_path(breakdown), params: params
        expect(zero_round.vote_rounds.reload.map(&:kind)).to eq([ "main" ])
      end
    end
  end

  describe "PATCH /judge/breakdowns/:breakdown_id/moves/:id" do
    let!(:host_speech) { speech(zero_round, 2) }
    let!(:move) { create(:breakdown_move, :nomination, breakdown_speech: host_speech, actor_seat: 2, target_seat: 7) }

    it "updates the move" do
      patch judge_breakdown_move_path(breakdown, move), params: { breakdown_move: { kind: "nomination", actor_seat: 2, target_seat: 8 } }
      expect(move.reload.target_seat).to eq(8)
    end

    it "keeps the move when the new attributes are invalid" do
      patch judge_breakdown_move_path(breakdown, move), params: { breakdown_move: { kind: "check_claim", actor_seat: 2 } }
      expect(move.reload.kind).to eq("nomination")
    end

    it "responds with unprocessable content when the new attributes are invalid" do
      patch judge_breakdown_move_path(breakdown, move), params: { breakdown_move: { kind: "check_claim", actor_seat: 2 } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "does not reach a move of another breakdown" do
      other = create(:game_breakdown, author: admin)

      patch judge_breakdown_move_path(other, move), params: { breakdown_move: { kind: "nomination", actor_seat: 2, target_seat: 8 } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /judge/breakdowns/:breakdown_id/moves/:id" do
    let!(:host_speech) { speech(zero_round, 2) }
    let!(:move) { create(:breakdown_move, :nomination, breakdown_speech: host_speech, actor_seat: 2, target_seat: 7) }

    it "deletes the move" do
      expect { delete judge_breakdown_move_path(breakdown, move) }.to change(BreakdownMove, :count).by(-1)
    end

    it "deletes a round move too" do
      round = vote(zero_round, "main")
      round_move = create(:breakdown_move, :other, breakdown_speech: nil, breakdown_vote_round: round, actor_seat: 3, text: "шум")

      expect { delete judge_breakdown_move_path(breakdown, round_move) }.to change(BreakdownMove, :count).by(-1)
    end
  end

  describe "PATCH /judge/breakdowns/:breakdown_id/vote_rounds/:id" do
    let!(:first_nomination) { nominate(zero_round, 1, 4) }
    let!(:second_nomination) { nominate(zero_round, 2, 5) }
    let!(:round) { create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "main", number: 1) }

    def ballots(choices)
      { votes: choices.transform_values { |seat| { candidate_seat: seat.to_s } } }
    end

    it "stores the submitted ballots" do
      patch judge_breakdown_vote_round_path(breakdown, round), params: ballots(1 => 4, 2 => 5)
      expect(round.votes.reload.map { |vote| [ vote.voter_seat, vote.candidate_seat ] }).to contain_exactly([ 1, 4 ], [ 2, 5 ])
    end

    it "updates an existing ballot" do
      create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 1, candidate_seat: 4)

      patch judge_breakdown_vote_round_path(breakdown, round), params: ballots(1 => 5)

      expect(round.votes.reload.map(&:candidate_seat)).to eq([ 5 ])
    end

    it "removes the ballot when the choice is cleared" do
      create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 1, candidate_seat: 4)

      patch judge_breakdown_vote_round_path(breakdown, round), params: { votes: { "1" => { candidate_seat: "" } } }

      expect(round.votes.reload).to be_empty
    end

    it "creates the farewell speech once the round eliminates a seat" do
      patch judge_breakdown_vote_round_path(breakdown, round),
            params: ballots((1..6).index_with { 4 }.merge((7..10).index_with { 5 }))

      expect(zero_round.speeches.reload.select(&:farewell?).map(&:speaker_seat)).to eq([ 4 ])
    end

    it "creates justification speeches and a revote on a tie" do
      patch judge_breakdown_vote_round_path(breakdown, round),
            params: ballots((1..5).index_with { 4 }.merge((6..10).index_with { 5 }))

      expect(zero_round.vote_rounds.reload.map(&:kind)).to eq([ "main", "revote" ])
    end

    it "stores lift ballots" do
      lift = create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "lift", number: 2)

      patch judge_breakdown_vote_round_path(breakdown, lift),
            params: { votes: { "1" => { for_lift: "true" }, "2" => { for_lift: "false" } } }

      expect(lift.votes.reload.map { |vote| [ vote.voter_seat, vote.for_lift ] }).to contain_exactly([ 1, true ], [ 2, false ])
    end

    it "ignores ballots for seats outside the table" do
      patch judge_breakdown_vote_round_path(breakdown, round), params: { votes: { "11" => { candidate_seat: "4" } } }
      expect(round.votes.reload).to be_empty
    end

    it "redirects back to the editor" do
      patch judge_breakdown_vote_round_path(breakdown, round), params: ballots(1 => 4)
      expect(response).to redirect_to(edit_judge_breakdown_path(breakdown))
    end
  end

  describe "DELETE /judge/breakdowns/:breakdown_id/vote_rounds/:id" do
    let!(:round) { vote(zero_round, "main", [ 1, 2 ] => 4) }

    it "deletes the round" do
      expect { delete judge_breakdown_vote_round_path(breakdown, round) }.to change(BreakdownVoteRound, :count).by(-1)
    end

    it "deletes its votes with it" do
      delete judge_breakdown_vote_round_path(breakdown, round)
      expect(BreakdownVote.count).to eq(0)
    end

    it "deletes its justification speeches with it" do
      revote = create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "revote", number: 2)
      create(:breakdown_speech, breakdown_phase: zero_round, speaker_seat: 4, kind: "justification", breakdown_vote_round: revote)

      delete judge_breakdown_vote_round_path(breakdown, revote)

      expect(zero_round.speeches.reload.select(&:justification?)).to be_empty
    end

    context "while the nominations still call for a vote" do
      before do
        nominate(zero_round, 1, 4)
        nominate(zero_round, 2, 5)
      end

      # The timeline still expects a main round, so the reset leaves an empty one rather than no voting at all.
      it "puts an empty round in its place" do
        delete judge_breakdown_vote_round_path(breakdown, round)
        expect(zero_round.vote_rounds.reload.map(&:kind)).to eq([ "main" ])
      end

      it "drops the recorded votes" do
        delete judge_breakdown_vote_round_path(breakdown, round)
        expect(BreakdownVote.count).to eq(0)
      end
    end

    context "once the nominations are gone" do
      it "leaves the phase without a vote round" do
        delete judge_breakdown_vote_round_path(breakdown, round)
        expect(zero_round.vote_rounds.reload).to be_empty
      end
    end
  end

  describe "turbo stream scope" do
    let!(:host_speech) { speech(zero_round, 2) }
    let!(:first_night) { night(1) }
    let!(:first_day) { day(2) }

    it "re-renders the edited phase" do
      post judge_breakdown_moves_path(breakdown),
           params: { speech_id: host_speech.id, breakdown_move: { kind: "nomination", actor_seat: 2, target_seat: 7 } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(zero_round)}"))
    end

    it "re-renders every following phase" do
      post judge_breakdown_moves_path(breakdown),
           params: { speech_id: host_speech.id, breakdown_move: { kind: "nomination", actor_seat: 2, target_seat: 7 } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(%(target="#{ActionView::RecordIdentifier.dom_id(first_night)}"))
        .and include(%(target="#{ActionView::RecordIdentifier.dom_id(first_day)}"))
    end

    it "leaves earlier phases alone" do
      create(:breakdown_move, :other, breakdown_speech: speech(first_day, 1), actor_seat: 1, text: "х")

      post judge_breakdown_moves_path(breakdown),
           params: { speech_id: first_day.speeches.first.id, breakdown_move: { kind: "other", actor_seat: 1, text: "ещё" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).not_to include(%(target="#{ActionView::RecordIdentifier.dom_id(zero_round)}"))
    end

    it "re-renders the footer" do
      post judge_breakdown_moves_path(breakdown),
           params: { speech_id: host_speech.id, breakdown_move: { kind: "nomination", actor_seat: 2, target_seat: 7 } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include('target="breakdown_footer"')
    end
  end
end
