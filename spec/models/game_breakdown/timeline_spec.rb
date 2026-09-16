require "rails_helper"

RSpec.describe GameBreakdown::Timeline do
  subject(:timeline) { described_class.new(breakdown) }

  let!(:breakdown) { create(:game_breakdown) }
  let(:zero_round) { breakdown.phases.find_by!(position: 0) }
  let(:zero_round_state) { timeline.state_for(zero_round) }

  include GameBreakdownHelpers

  def elimination(seat, reason)
    described_class::Elimination.new(seat: seat, reason: reason)
  end

  describe "a fresh breakdown" do
    it "has only the zero round" do
      expect(timeline.phases.map(&:phase)).to eq([ zero_round ])
    end

    it "labels the zero round" do
      expect(zero_round_state.label).to eq("Нулевой круг")
    end

    it "starts with all seats alive" do
      expect(zero_round_state.alive_at_start).to eq((1..10).to_a)
    end

    it "starts the zero round at seat 1" do
      expect(zero_round_state.starter).to eq(1)
    end

    it "orders speeches from seat 1" do
      expect(zero_round_state.speech_order).to eq((1..10).to_a)
    end

    it "has no farewell speech" do
      expect(zero_round_state.farewell_seat).to be_nil
    end

    it "expects nothing" do
      expect(zero_round_state.expected_steps).to be_empty
    end

    it "has no result" do
      expect(timeline.result).to be_nil
    end

    it "is not finished" do
      expect(timeline).not_to be_finished
    end

    it "plans a night as the next phase" do
      expect(timeline.next_phase).to eq(described_class::NextPhase.new(position: 1, kind: :night, farewell_seat: nil, speech_order: []))
    end
  end

  describe "nights" do
    context "when the night ends with a kill" do
      let!(:first_night) { night(1, killed: 4) }
      let(:state) { timeline.state_for(first_night) }

      it "labels the night by its number" do
        expect(state.label).to eq("Ночь 1")
      end

      it "eliminates the killed seat" do
        expect(state.eliminations).to eq([ elimination(4, :night_kill) ])
      end

      it "removes the killed seat from alive seats" do
        expect(state.alive_at_end).to eq([ 1, 2, 3, 5, 6, 7, 8, 9, 10 ])
      end

      it "plans a day opened by the farewell speech of the killed seat" do
        expect(timeline.next_phase).to eq(
          described_class::NextPhase.new(position: 2, kind: :day, farewell_seat: 4, speech_order: [ 2, 3, 5, 6, 7, 8, 9, 10, 1 ])
        )
      end
    end

    context "when the night ends with a miss" do
      let!(:first_night) { night(1) }

      it "eliminates nobody" do
        expect(timeline.state_for(first_night).eliminations).to be_empty
      end
    end

    context "when the night is not filled" do
      let!(:first_night) { create(:breakdown_phase, :night, game_breakdown: breakdown, position: 1) }

      it "eliminates nobody" do
        expect(timeline.state_for(first_night).alive_at_end).to eq((1..10).to_a)
      end
    end

    context "when the killed seat is already eliminated" do
      let!(:first_night) { night(1, killed: 4) }
      let!(:third_night) { night(3, killed: 4) }

      before { day(2) }

      it "eliminates nobody again" do
        expect(timeline.state_for(third_night).eliminations).to be_empty
      end
    end
  end

  describe "day labels" do
    context "when a night kill happened" do
      let!(:second_day) { day(2) }

      before { night(1, killed: 4) }

      it "labels the day by alive count" do
        expect(timeline.state_for(second_day).label).to eq("Круг при 9")
      end
    end

    context "when the night was a miss" do
      let!(:second_day) { day(2) }

      before { night(1) }

      it "keeps the alive count" do
        expect(timeline.state_for(second_day).label).to eq("Круг при 10")
      end
    end

    context "when three players are alive" do
      let!(:second_day) { day(2) }

      before do
        remove(zero_round, 4, 5, 6, 7, 8, 9, 10)
        night(1)
      end

      it "labels the day as the final three" do
        expect(timeline.state_for(second_day).label).to eq("Угадайка на троих")
      end
    end
  end

  describe "speech order" do
    context "when the next seat after the previous starter was killed" do
      let!(:second_day) { day(2) }
      let(:state) { timeline.state_for(second_day) }

      before { night(1, killed: 2) }

      it "starts at the next alive seat" do
        expect(state.starter).to eq(3)
      end

      it "orders speeches circularly from the starter" do
        expect(state.speech_order).to eq([ 3, 4, 5, 6, 7, 8, 9, 10, 1 ])
      end

      it "opens with the farewell speech of the killed seat" do
        expect(state.farewell_seat).to eq(2)
      end
    end

    context "when the previous starter is the last alive seat" do
      let!(:fourth_day) { day(4) }

      before do
        remove(zero_round, 2, 3, 4, 5, 6, 7, 8, 9)
        night(1)
        day(2)
        night(3)
      end

      it "starts the second day after the previous starter" do
        expect(timeline.state_for(breakdown.phases.find_by!(position: 2)).starter).to eq(10)
      end

      it "wraps around to the first alive seat" do
        expect(timeline.state_for(fourth_day).starter).to eq(1)
      end

      it "has no farewell speech after a miss" do
        expect(timeline.state_for(fourth_day).farewell_seat).to be_nil
      end
    end
  end

  describe "nominations" do
    before do
      nominate(zero_round, 1, 5)
      nominate(zero_round, 2, 3)
      nominate(zero_round, 4, 5)
    end

    it "lists nominations in speech order" do
      expect(zero_round_state.nominations).to eq([
        described_class::Nomination.new(actor_seat: 1, target_seat: 5),
        described_class::Nomination.new(actor_seat: 2, target_seat: 3),
        described_class::Nomination.new(actor_seat: 4, target_seat: 5)
      ])
    end

    it "derives unique candidates in nomination order" do
      expect(zero_round_state.candidates).to eq([ 5, 3 ])
    end

    context "when a nomination targets an eliminated seat" do
      let!(:second_day) { day(2) }

      before do
        night(1, killed: 7)
        nominate(second_day, 1, 7)
        nominate(second_day, 2, 8)
      end

      it "skips the eliminated seat" do
        expect(timeline.state_for(second_day).candidates).to eq([ 8 ])
      end
    end

    context "when several moves in one speech nominate" do
      let(:shared_speech) { speech(zero_round, 6) }

      before do
        create(:breakdown_move, :nomination, breakdown_speech: shared_speech, actor_seat: 6, target_seat: 9, position: 2)
        create(:breakdown_move, :nomination, breakdown_speech: shared_speech, actor_seat: 6, target_seat: 8, position: 1)
      end

      it "orders them by move position" do
        expect(zero_round_state.candidates).to eq([ 5, 3, 8, 9 ])
      end
    end
  end

  describe "voting" do
    context "when a zero round has a single nominee" do
      before { nominate(zero_round, 1, 5) }

      it "does not expect voting" do
        expect(zero_round_state.expected_steps).to be_empty
      end
    end

    context "when a later day has a single nominee and no round" do
      let!(:second_day) { day(2) }

      before do
        night(1)
        nominate(second_day, 1, 5)
      end

      it "expects the main round" do
        expect(timeline.state_for(second_day).expected_steps).to eq([ described_class::ExpectedStep.new(kind: :main_round, seats: [ 5 ]) ])
      end
    end

    context "when the zero round has two nominees and no round" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
      end

      it "expects the main round" do
        expect(zero_round_state.expected_steps).to eq([ described_class::ExpectedStep.new(kind: :main_round, seats: [ 5, 3 ]) ])
      end
    end

    context "when a round has no votes yet" do
      let(:round_result) { zero_round_state.vote_rounds.first }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main")
      end

      it "is pending" do
        expect(round_result.outcome).to eq(:pending)
      end

      it "expects nothing" do
        expect(zero_round_state.expected_steps).to be_empty
      end
    end

    context "when one candidate has the most votes" do
      let(:round_result) { zero_round_state.vote_rounds.first }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 5, 8, 9, 10 ] => 3)
      end

      it "tallies voters per candidate" do
        expect(round_result.tally).to eq(5 => [ 1, 2, 3, 4, 6, 7 ], 3 => [ 5, 8, 9, 10 ])
      end

      it "eliminates the leader" do
        expect(round_result).to have_attributes(outcome: :eliminated, leaders: [ 5 ], eliminated: [ 5 ])
      end

      it "records the vote elimination" do
        expect(zero_round_state.eliminations).to eq([ elimination(5, :vote) ])
      end

      it "removes the seat from alive seats" do
        expect(zero_round_state.alive_at_end).not_to include(5)
      end

      it "expects a farewell speech" do
        expect(zero_round_state.expected_steps).to eq([ described_class::ExpectedStep.new(kind: :farewell_speeches, seats: [ 5 ]) ])
      end

      context "when the farewell speech exists" do
        before { speech(zero_round, 5, kind: "farewell") }

        it "expects nothing" do
          expect(zero_round_state.expected_steps).to be_empty
        end
      end
    end

    context "when some players did not vote" do
      let(:round_result) { zero_round_state.vote_rounds.first }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4 ] => 5)
      end

      it "counts their votes for the last nominee" do
        expect(round_result.tally).to eq(5 => [ 1, 2, 3, 4 ], 3 => [ 5, 6, 7, 8, 9, 10 ])
      end
    end

    context "when votes are cast for a non-candidate or by an eliminated seat" do
      let!(:second_day) { day(2) }
      let(:round_result) { timeline.state_for(second_day).vote_rounds.first }

      before do
        night(1, killed: 10)
        nominate(second_day, 1, 5)
        nominate(second_day, 2, 3)
        vote(second_day, "main", [ 1, 2, 3 ] => 5, [ 4 ] => 7, [ 10 ] => 5, [ 5, 6, 7, 8, 9 ] => 3)
      end

      it "ignores them" do
        expect(round_result.tally).to eq(5 => [ 1, 2, 3 ], 3 => [ 5, 6, 7, 8, 9 ])
      end
    end

    context "when a round has only votes by eliminated seats" do
      let!(:second_day) { day(2) }
      let(:round_result) { timeline.state_for(second_day).vote_rounds.first }

      before do
        night(1, killed: 10)
        nominate(second_day, 1, 5)
        nominate(second_day, 2, 3)
        vote(second_day, "main", [ 10 ] => 5)
      end

      it "is pending" do
        expect(round_result).to have_attributes(outcome: :pending, eliminated: [])
      end
    end

    context "when a lift round has only votes by eliminated seats" do
      let!(:second_day) { day(2) }
      let(:lift_result) { timeline.state_for(second_day).vote_rounds.third }

      before do
        night(1, killed: 10)
        nominate(second_day, 1, 5)
        nominate(second_day, 2, 3)
        vote(second_day, "main", [ 1, 2, 3, 4 ] => 5, [ 5, 6, 7, 8 ] => 3, [ 9 ] => 7)
        vote(second_day, "revote", [ 1, 2, 3, 4 ] => 5, [ 5, 6, 7, 8 ] => 3, [ 9 ] => 7)
        vote(second_day, "lift", [ 10 ] => true)
      end

      it "is pending" do
        expect(lift_result).to have_attributes(outcome: :pending, eliminated: [])
      end
    end

    context "when the main round ends in a tie" do
      let(:round_result) { zero_round_state.vote_rounds.first }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        nominate(zero_round, 4, 8)
        vote(zero_round, "main", [ 1, 2, 3, 4 ] => 8, [ 5, 6, 7, 9 ] => 3, [ 8, 10 ] => 5)
      end

      it "reports a tie between the leaders in nomination order" do
        expect(round_result).to have_attributes(outcome: :tie, leaders: [ 3, 8 ], eliminated: [])
      end

      it "expects justification speeches and a revote" do
        expect(zero_round_state.expected_steps).to eq([ described_class::ExpectedStep.new(kind: :revote_round, seats: [ 3, 8 ]) ])
      end

      it "eliminates nobody yet" do
        expect(zero_round_state.eliminations).to be_empty
      end
    end

    context "when every main round candidate is tied" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3)
      end

      it "still expects a revote first" do
        expect(zero_round_state.expected_steps).to eq([ described_class::ExpectedStep.new(kind: :revote_round, seats: [ 5, 3 ]) ])
      end
    end

    context "when a revote ends in a tie among fewer candidates" do
      let(:revote_result) { zero_round_state.vote_rounds.second }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        nominate(zero_round, 4, 8)
        vote(zero_round, "main", [ 1, 2, 3 ] => 5, [ 4, 6, 7 ] => 3, [ 5, 8, 9 ] => 8, [ 10 ] => 7)
        vote(zero_round, "revote", [ 1, 2, 3, 4 ] => 5, [ 5, 6, 7, 9 ] => 8, [ 8 ] => 3, [ 10 ] => 7)
      end

      it "uses the tied seats of the previous round as candidates" do
        expect(revote_result.candidates).to eq([ 5, 3, 8 ])
      end

      it "ignores votes for seats outside the revote" do
        expect(revote_result.tally).to eq(5 => [ 1, 2, 3, 4 ], 3 => [ 8 ], 8 => [ 5, 6, 7, 9 ])
      end

      it "expects another revote" do
        expect(zero_round_state.expected_steps).to eq([ described_class::ExpectedStep.new(kind: :revote_round, seats: [ 5, 8 ]) ])
      end
    end

    context "when a revote ends in a tie among the same number of candidates" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3)
        vote(zero_round, "revote", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3)
      end

      it "expects a lift round" do
        expect(zero_round_state.expected_steps).to eq([ described_class::ExpectedStep.new(kind: :lift_round, seats: [ 5, 3 ]) ])
      end
    end

    context "when a revote ends with a single leader" do
      let(:revote_result) { zero_round_state.vote_rounds.second }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3)
        vote(zero_round, "revote", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 5, 8, 9, 10 ] => 3)
      end

      it "eliminates the leader" do
        expect(zero_round_state.eliminations).to eq([ elimination(5, :vote) ])
      end
    end

    context "when a revote follows a round without a tie" do
      let(:revote_result) { zero_round_state.vote_rounds.second }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 5, 8, 9, 10 ] => 3)
        vote(zero_round, "revote", [ 1 ] => 5)
      end

      it "has no candidates" do
        expect(revote_result).to have_attributes(candidates: [], outcome: :pending)
      end
    end

    describe "lift round" do
      let(:lift_result) { zero_round_state.vote_rounds.third }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3)
        vote(zero_round, "revote", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3)
      end

      context "when strictly more than half vote to lift" do
        before { vote(zero_round, "lift", [ 1, 2, 3, 4, 5, 6 ] => true, [ 7, 8, 9, 10 ] => false) }

        it "eliminates every candidate" do
          expect(lift_result).to have_attributes(outcome: :lift_passed, candidates: [ 5, 3 ], eliminated: [ 5, 3 ])
        end

        it "tallies voters for and against" do
          expect(lift_result.tally).to eq(for: [ 1, 2, 3, 4, 5, 6 ], against: [ 7, 8, 9, 10 ])
        end

        it "records vote eliminations" do
          expect(zero_round_state.eliminations).to eq([ elimination(5, :vote), elimination(3, :vote) ])
        end

        it "expects farewell speeches for both" do
          expect(zero_round_state.expected_steps).to eq([ described_class::ExpectedStep.new(kind: :farewell_speeches, seats: [ 5, 3 ]) ])
        end
      end

      context "when exactly half vote to lift" do
        before { vote(zero_round, "lift", [ 1, 2, 3, 4, 5 ] => true) }

        it "eliminates nobody" do
          expect(lift_result).to have_attributes(outcome: :lift_failed, eliminated: [])
        end

        it "counts missing votes as against" do
          expect(lift_result.tally).to eq(for: [ 1, 2, 3, 4, 5 ], against: [ 6, 7, 8, 9, 10 ])
        end

        it "expects nothing" do
          expect(zero_round_state.expected_steps).to be_empty
        end
      end

      context "when the lift round has no votes yet" do
        before { vote(zero_round, "lift") }

        it "is pending" do
          expect(lift_result.outcome).to eq(:pending)
        end
      end
    end
  end

  describe "removals" do
    context "when a player is removed during speeches" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        remove(zero_round, 7)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 9, 10 ] => 3)
      end

      it "eliminates the removed player" do
        expect(zero_round_state.eliminations).to eq([ elimination(7, :removal) ])
      end

      it "cancels the voting" do
        expect(zero_round_state).to be_voting_cancelled
      end

      it "keeps everyone else alive" do
        expect(zero_round_state.alive_at_end).to eq([ 1, 2, 3, 4, 5, 6, 8, 9, 10 ])
      end

      it "expects nothing" do
        expect(zero_round_state.expected_steps).to be_empty
      end
    end

    context "when a player is removed during a vote round" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        round = vote(zero_round, "main", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 5, 8, 9, 10 ] => 3)
        create(:breakdown_move, :removal, :in_vote_round, breakdown_vote_round: round, actor_seat: 9)
      end

      it "cancels the voting" do
        expect(zero_round_state.eliminations).to eq([ elimination(9, :removal) ])
      end
    end

    context "when a voted-out player is removed in the farewell speech" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 5, 8, 9, 10 ] => 3)
        remove(zero_round, 5, kind: "farewell")
      end

      it "keeps the voting result" do
        expect(zero_round_state).to have_attributes(voting_cancelled: false, eliminations: [ elimination(5, :vote) ])
      end
    end

    context "when an already eliminated player gets a removal" do
      let!(:second_day) { day(2) }

      before do
        night(1, killed: 4)
        create(:breakdown_move, :removal, breakdown_speech: speech(second_day, 1), actor_seat: 4)
      end

      it "does not cancel the voting" do
        expect(timeline.state_for(second_day)).not_to be_voting_cancelled
      end
    end
  end

  describe "result" do
    context "when roles are unknown" do
      before { breakdown.update!(manual_result: "draw") }

      it "uses the manual result" do
        expect(timeline.result).to eq("draw")
      end

      it "is not computed" do
        expect(timeline).not_to be_result_computed
      end

      it "is finished" do
        expect(timeline).to be_finished
      end

      it "plans no next phase" do
        expect(timeline.next_phase).to be_nil
      end
    end

    context "when roles are known and every mafia member is eliminated" do
      before do
        assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4)
        breakdown.update!(manual_result: "mafia")
        night(1, killed: 1)
        day(2)
        night(3, killed: 2)
        day(4)
        night(5, killed: 3)
      end

      it "computes a city win over the manual result" do
        expect(timeline.result).to eq("city")
      end

      it "is computed" do
        expect(timeline).to be_result_computed
      end
    end

    context "when mafia reach parity with the city" do
      before do
        assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4)
        night(1, killed: 4)
        day(2)
        night(3, killed: 5)
        day(4)
        night(5, killed: 6)
        day(6)
        night(7, killed: 7)
      end

      it "computes a mafia win" do
        expect(timeline.result).to eq("mafia")
      end

      it "plans no next phase" do
        expect(timeline.next_phase).to be_nil
      end
    end

    context "when mafia are one short of parity" do
      before do
        assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4)
        night(1, killed: 4)
        day(2)
        night(3, killed: 5)
        day(4)
        night(5, killed: 6)
      end

      it "has no result" do
        expect(timeline.result).to be_nil
      end
    end

    context "when nobody leaves through three consecutive nights" do
      before do
        assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4)
        night(1)
        day(2)
        night(3)
        day(4)
        night(5)
      end

      it "computes a draw" do
        expect(timeline.result).to eq("draw")
      end
    end

    context "when nobody leaves through only two consecutive nights" do
      before do
        assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4)
        night(1, killed: 5)
        day(2)
        night(3)
        day(4)
        night(5)
      end

      it "has no result" do
        expect(timeline.result).to be_nil
      end
    end

    context "when a day elimination breaks the three-night streak" do
      before do
        assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4)
        night(1)
        remove(day(2), 9)
        night(3)
        day(4)
        night(5)
      end

      it "has no result" do
        expect(timeline.result).to be_nil
      end
    end

    context "when one seat has no role" do
      before do
        assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4)
        breakdown.seats.where(number: 10).update_all(role_code: nil)
        night(1)
        day(2)
        night(3)
        day(4)
        night(5)
      end

      it "does not compute a result" do
        expect(timeline.result).to be_nil
      end
    end
  end

  describe "#warnings_for" do
    let!(:second_day) { day(2) }
    let!(:late_speech) { speech(second_day, 4) }
    let!(:alive_speech) { speech(second_day, 1) }

    before do
      breakdown.update!(roles_mode: "closed")
      night(1, killed: 4)
    end

    it "returns the warnings attached to the record" do
      expect(timeline.warnings_for(late_speech)).to eq([ described_class::Warning.for_seat(:eliminated_speaker, late_speech, 4) ])
    end

    it "returns nothing for a record without warnings" do
      expect(timeline.warnings_for(alive_speech)).to be_empty
    end

    it "lists every warning" do
      expect(timeline.warnings).to eq([ described_class::Warning.for_seat(:eliminated_speaker, late_speech, 4) ])
    end
  end

  describe "#state_for" do
    context "when the phase belongs to the breakdown" do
      let!(:first_night) { night(1, killed: 4) }

      it "returns the state of that phase" do
        expect(timeline.state_for(BreakdownPhase.find(first_night.id))).to have_attributes(phase: first_night, label: "Ночь 1")
      end
    end

    context "when the phase belongs to another breakdown" do
      let(:foreign_phase) { create(:game_breakdown).phases.first }

      it "returns nil" do
        expect(timeline.state_for(foreign_phase)).to be_nil
      end
    end
  end
end
