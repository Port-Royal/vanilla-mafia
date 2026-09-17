require "rails_helper"

RSpec.describe GameBreakdown::Timeline::Warnings do
  include GameBreakdownHelpers

  let!(:breakdown) { create(:game_breakdown, roles_mode: "closed") }
  let(:timeline) { GameBreakdown::Timeline.new(breakdown) }
  let(:zero_round) { breakdown.phases.find_by!(position: 0) }

  def warning(code, record, rule: nil, **details)
    GameBreakdown::Timeline::Warning.new(code: code, record: record, rule: rule, details: details)
  end

  def best_move(phase, seat, kind: "farewell")
    create(:breakdown_move, :best_move, breakdown_speech: speech(phase, seat, kind: kind), actor_seat: seat)
  end

  def tie_twice(phase, ballots)
    vote(phase, "main", ballots)
    vote(phase, "revote", ballots)
  end

  describe "a fresh breakdown" do
    it "has no warnings" do
      expect(timeline.warnings).to be_empty
    end
  end

  describe "speeches" do
    context "when an eliminated seat speaks" do
      let!(:second_day) { day(2) }
      let!(:late_speech) { speech(second_day, 4) }

      before { night(1, killed: 4) }

      it "warns about the speaker" do
        expect(timeline.warnings_for(late_speech)).to eq([ warning(:eliminated_speaker, late_speech, seat: 4) ])
      end
    end

    context "when the night-killed seat gives its farewell speech" do
      let!(:second_day) { day(2) }
      let!(:farewell) { speech(second_day, 4, kind: "farewell") }

      before { night(1, killed: 4) }

      it "does not warn" do
        expect(timeline.warnings_for(farewell)).to be_empty
      end
    end

    context "when a seat that did not leave gives a farewell speech" do
      let!(:farewell) { speech(zero_round, 6, kind: "farewell") }

      it "warns about the farewell speech" do
        expect(timeline.warnings_for(farewell)).to eq([ warning(:unexpected_farewell, farewell, seat: 6) ])
      end
    end

    context "when the voted-out seat gives a farewell speech" do
      let!(:farewell) { speech(zero_round, 5, kind: "farewell") }

      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 5, 8, 9, 10 ] => 3)
      end

      it "does not warn" do
        expect(timeline.warnings_for(farewell)).to be_empty
      end
    end

    context "when a removed seat gives a farewell speech" do
      let!(:farewell) { speech(zero_round, 7, kind: "farewell") }

      before { remove(zero_round, 7) }

      it "warns about the farewell speech" do
        expect(timeline.warnings_for(farewell)).to eq([ warning(:unexpected_farewell, farewell, seat: 7) ])
      end
    end

    context "when justification speeches precede a revote" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        nominate(zero_round, 4, 8)
        vote(zero_round, "main", [ 1, 2, 3, 4 ] => 8, [ 5, 6, 7, 9 ] => 3, [ 8, 10 ] => 5)
      end

      let!(:revote) { vote(zero_round, "revote") }
      let!(:candidate_speech) { speech(zero_round, 3, kind: "justification", round: revote) }
      let!(:outsider_speech) { speech(zero_round, 5, kind: "justification", round: revote) }

      it "does not warn about a candidate" do
        expect(timeline.warnings_for(candidate_speech)).to be_empty
      end

      it "warns about a seat outside the revote" do
        expect(timeline.warnings_for(outsider_speech)).to eq([ warning(:unexpected_justification, outsider_speech, seat: 5) ])
      end
    end
  end

  describe "moves" do
    context "when an eliminated seat acts in another player's speech" do
      let!(:second_day) { day(2) }
      let!(:move) { create(:breakdown_move, :check_request, breakdown_speech: speech(second_day, 1), actor_seat: 4, target_seat: 2) }

      before { night(1, killed: 4) }

      it "warns about the actor" do
        expect(timeline.warnings_for(move)).to eq([ warning(:eliminated_actor, move, seat: 4) ])
      end
    end

    context "when the night-killed seat acts in its farewell speech" do
      let!(:second_day) { day(2) }
      let!(:move) { create(:breakdown_move, breakdown_speech: speech(second_day, 4, kind: "farewell"), actor_seat: 4) }

      before { night(1, killed: 4) }

      it "does not warn" do
        expect(timeline.warnings_for(move)).to be_empty
      end
    end

    context "when another eliminated seat acts in the farewell speech" do
      let!(:second_day) { day(2) }
      let!(:move) { create(:breakdown_move, breakdown_speech: speech(second_day, 4, kind: "farewell"), actor_seat: 9) }

      before do
        remove(zero_round, 9)
        night(1, killed: 4)
      end

      it "warns about the actor" do
        expect(timeline.warnings_for(move)).to eq([ warning(:eliminated_actor, move, seat: 9) ])
      end
    end

    context "when an eliminated seat acts in a vote round" do
      let!(:second_day) { day(2) }

      before do
        night(1, killed: 4)
        nominate(second_day, 1, 5)
      end

      let!(:move) { create(:breakdown_move, :in_vote_round, breakdown_vote_round: vote(second_day, "main"), actor_seat: 4) }

      it "warns about the actor" do
        expect(timeline.warnings_for(move)).to eq([ warning(:eliminated_actor, move, seat: 4) ])
      end
    end

    %w[nomination check_request protection sheriff_reveal_to_player split_break].each do |kind|
      context "when a #{kind} targets an eliminated seat" do
        let!(:second_day) { day(2) }
        let!(:move) { create(:breakdown_move, kind.to_sym, breakdown_speech: speech(second_day, 1), actor_seat: 1, target_seat: 4) }

        before { night(1, killed: 4) }

        it "warns about the target" do
          expect(timeline.warnings_for(move)).to eq([ warning(:eliminated_target, move, seat: 4) ])
        end
      end
    end

    context "when a check claim names an eliminated seat" do
      let!(:second_day) { day(2) }
      let!(:move) { create(:breakdown_move, :check_claim, breakdown_speech: speech(second_day, 1), target_seat: 4) }

      before { night(1, killed: 4) }

      it "does not warn" do
        expect(timeline.warnings_for(move)).to be_empty
      end
    end

    context "when a split break has no target" do
      let!(:move) { create(:breakdown_move, :split_break, breakdown_speech: speech(zero_round, 1), target_seat: nil) }

      it "does not warn" do
        expect(timeline.warnings_for(move)).to be_empty
      end
    end

    context "when a player nominates twice in a day" do
      let!(:first_nomination) { nominate(zero_round, 1, 5) }
      let!(:second_nomination) { nominate(zero_round, 1, 3) }

      it "warns about the second nomination" do
        expect(timeline.warnings_for(second_nomination)).to eq([ warning(:repeated_nomination, second_nomination, rule: "4.4.2", seat: 1) ])
      end

      it "does not warn about the first nomination" do
        expect(timeline.warnings_for(first_nomination)).to be_empty
      end
    end

    context "when different players nominate" do
      let!(:nomination) { nominate(zero_round, 2, 5) }

      before { nominate(zero_round, 1, 5) }

      it "does not warn" do
        expect(timeline.warnings_for(nomination)).to be_empty
      end
    end

    context "when a player nominates on different days" do
      let!(:second_day) { day(2) }
      let!(:nomination) { nominate(second_day, 1, 3) }

      before do
        nominate(zero_round, 1, 5)
        night(1)
      end

      it "does not warn" do
        expect(timeline.warnings_for(nomination)).to be_empty
      end
    end

    context "when a check claim names a night that has not passed" do
      let!(:second_day) { day(2) }
      let!(:claim) { create(:breakdown_move, :check_claim, breakdown_speech: speech(second_day, 1), night_number: 2) }

      before { night(1) }

      it "warns about the claim" do
        expect(timeline.warnings_for(claim)).to eq([ warning(:check_claim_night_out_of_range, claim, night: 2) ])
      end
    end

    context "when a check claim names the last passed night" do
      let!(:second_day) { day(2) }
      let!(:claim) { create(:breakdown_move, :check_claim, breakdown_speech: speech(second_day, 1), night_number: 1) }

      before { night(1) }

      it "does not warn" do
        expect(timeline.warnings_for(claim)).to be_empty
      end
    end
  end

  describe "best move" do
    context "when the first night-killed player makes it in the farewell speech" do
      let!(:second_day) { day(2) }
      let!(:move) { best_move(second_day, 4) }

      before { night(1, killed: 4) }

      it "does not warn" do
        expect(timeline.warnings_for(move)).to be_empty
      end
    end

    context "when one player left the zero round" do
      let!(:second_day) { day(2) }
      let!(:move) { best_move(second_day, 4) }

      before do
        remove(zero_round, 10)
        night(1, killed: 4)
      end

      it "does not warn" do
        expect(timeline.warnings_for(move)).to be_empty
      end
    end

    context "when two players left the zero round" do
      let!(:second_day) { day(2) }
      let!(:move) { best_move(second_day, 4) }

      before do
        remove(zero_round, 9, 10)
        night(1, killed: 4)
      end

      it "warns about the move" do
        expect(timeline.warnings_for(move)).to eq([ warning(:best_move_without_right, move, rule: "6.11.4") ])
      end
    end

    context "when the player was killed on a later night" do
      let!(:fourth_day) { day(4) }
      let!(:move) { best_move(fourth_day, 4) }

      before do
        night(1)
        day(2)
        night(3, killed: 4)
      end

      it "warns about the move" do
        expect(timeline.warnings_for(move)).to eq([ warning(:best_move_without_right, move, rule: "6.11.4") ])
      end
    end

    context "when it is made in a regular speech" do
      let!(:second_day) { day(2) }
      let!(:move) { best_move(second_day, 1, kind: "regular") }

      before { night(1, killed: 4) }

      it "warns about the move" do
        expect(timeline.warnings_for(move)).to eq([ warning(:best_move_without_right, move, rule: "6.11.4") ])
      end
    end

    describe "in the zero round" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
        vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3)
      end

      context "when a player leaves after a split break" do
        before do
          create(:breakdown_move, :split_break, breakdown_speech: speech(zero_round, 8), actor_seat: 8)
          vote(zero_round, "revote", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 7, 9, 10 ] => 3)
        end

        let!(:move) { best_move(zero_round, 5) }

        it "does not warn" do
          expect(timeline.warnings_for(move)).to be_empty
        end
      end

      context "when a player leaves without a split break" do
        before { vote(zero_round, "revote", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 7, 9, 10 ] => 3) }

        let!(:move) { best_move(zero_round, 5) }

        it "warns about the move" do
          expect(timeline.warnings_for(move)).to eq([ warning(:best_move_without_right, move, rule: "4.4.20") ])
        end
      end

      # 7.5.8: a player who broke the split onto themselves forfeits the day best move.
      context "when the leaving player broke the split into themselves" do
        before do
          create(:breakdown_move, :split_break, breakdown_speech: speech(zero_round, 5), actor_seat: 5, target_seat: 5)
          vote(zero_round, "revote", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 7, 9, 10 ] => 3)
        end

        let!(:move) { best_move(zero_round, 5) }

        it "warns about the move" do
          expect(timeline.warnings_for(move)).to eq([ warning(:best_move_without_right, move, rule: "7.5.8") ])
        end
      end

      context "when the leaving player broke the split into someone else" do
        before do
          create(:breakdown_move, :split_break, breakdown_speech: speech(zero_round, 5), actor_seat: 5, target_seat: 7)
          vote(zero_round, "revote", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 7, 9, 10 ] => 3)
        end

        let!(:move) { best_move(zero_round, 5) }

        it "does not warn" do
          expect(timeline.warnings_for(move)).to be_empty
        end
      end

      context "when someone else broke the split into the leaving player" do
        before do
          create(:breakdown_move, :split_break, breakdown_speech: speech(zero_round, 8), actor_seat: 8, target_seat: 5)
          vote(zero_round, "revote", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 7, 9, 10 ] => 3)
        end

        let!(:move) { best_move(zero_round, 5) }

        it "does not warn" do
          expect(timeline.warnings_for(move)).to be_empty
        end
      end

      context "when a player who stayed makes it after a split break" do
        before do
          create(:breakdown_move, :split_break, breakdown_speech: speech(zero_round, 8), actor_seat: 8)
          vote(zero_round, "revote", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 7, 9, 10 ] => 3)
        end

        let!(:move) { best_move(zero_round, 7) }

        it "warns about the move" do
          expect(timeline.warnings_for(move)).to eq([ warning(:best_move_without_right, move, rule: "4.4.20") ])
        end
      end

      context "when a leaving player makes it in a regular speech after a split break" do
        before do
          create(:breakdown_move, :split_break, breakdown_speech: speech(zero_round, 8), actor_seat: 8)
          vote(zero_round, "revote", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 7, 9, 10 ] => 3)
        end

        let!(:move) { best_move(zero_round, 5, kind: "regular") }

        it "warns about the move" do
          expect(timeline.warnings_for(move)).to eq([ warning(:best_move_without_right, move, rule: "4.4.20") ])
        end
      end
    end
  end

  describe "votes" do
    context "when a vote is cast for a non-candidate" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
      end

      let!(:round) { vote(zero_round, "main", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 8 ] => 7, [ 5, 9, 10 ] => 3) }
      let(:stray_vote) { round.votes.find_by!(voter_seat: 8) }

      it "warns about the vote" do
        expect(timeline.warnings_for(stray_vote)).to eq([ warning(:non_candidate_vote, stray_vote, seat: 7) ])
      end

      it "does not warn about a vote for a candidate" do
        expect(timeline.warnings_for(round.votes.find_by!(voter_seat: 1))).to be_empty
      end
    end

    context "when an eliminated seat votes" do
      let!(:second_day) { day(2) }

      before do
        night(1, killed: 10)
        nominate(second_day, 1, 5)
        nominate(second_day, 2, 3)
      end

      let!(:round) { vote(second_day, "main", [ 1, 2, 3, 10 ] => 5, [ 4, 5, 6, 7, 8, 9 ] => 3) }
      let(:dead_vote) { round.votes.find_by!(voter_seat: 10) }

      it "warns about the voter" do
        expect(timeline.warnings_for(dead_vote)).to eq([ warning(:eliminated_actor, dead_vote, seat: 10) ])
      end
    end

    context "when a round has no candidates" do
      let!(:round) { vote(zero_round, "main", [ 1 ] => 5) }

      it "does not warn about the votes" do
        expect(timeline.warnings_for(round.votes.first)).to be_empty
      end
    end
  end

  describe "vote rounds" do
    context "when the zero round has a single nominee and a vote round" do
      before { nominate(zero_round, 1, 5) }

      let!(:round) { vote(zero_round, "main", [ 1 ] => 5) }

      it "warns about the round" do
        expect(timeline.warnings_for(round)).to eq([ warning(:zero_round_single_nominee_voting, round, rule: "4.4.11") ])
      end
    end

    context "when a later day has a single nominee and a vote round" do
      let!(:second_day) { day(2) }

      before do
        night(1)
        nominate(second_day, 1, 5)
      end

      let!(:round) { vote(second_day, "main", [ 1 ] => 5) }

      it "does not warn" do
        expect(timeline.warnings_for(round)).to be_empty
      end
    end

    context "when the zero round has two nominees and a vote round" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
      end

      let!(:round) { vote(zero_round, "main", [ 1 ] => 5) }

      it "does not warn" do
        expect(timeline.warnings_for(round)).to be_empty
      end
    end

    context "when a zero round revote follows a single nominee round" do
      before do
        nominate(zero_round, 1, 5)
        vote(zero_round, "main", [ 1 ] => 5)
      end

      let!(:revote) { vote(zero_round, "revote") }

      it "warns only that the round is unexpected" do
        expect(timeline.warnings_for(revote)).to eq([ warning(:unexpected_vote_round, revote) ])
      end
    end

    describe "after a removal" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
      end

      context "when the removal happens in a speech" do
        before { remove(zero_round, 7) }

        let!(:round) { vote(zero_round, "main", [ 1, 2, 3, 4, 6, 8 ] => 5, [ 5, 9, 10 ] => 3) }

        it "warns about the round" do
          expect(timeline.warnings_for(round)).to eq([ warning(:voting_after_removal, round, rule: "4.4.15") ])
        end
      end

      context "when the removal happens inside a vote round" do
        let!(:main_round) { vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3) }
        let!(:revote) do
          create(:breakdown_move, :removal, :in_vote_round, breakdown_vote_round: main_round, actor_seat: 9)
          vote(zero_round, "revote")
        end

        it "warns about the later round" do
          expect(timeline.warnings_for(revote)).to eq([ warning(:voting_after_removal, revote, rule: "4.4.15") ])
        end

        it "does not warn about the round of the removal" do
          expect(timeline.warnings_for(main_round)).to be_empty
        end
      end

      context "when the removal happens in a justification speech" do
        let!(:main_round) { vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3) }
        let!(:revote) { vote(zero_round, "revote") }

        before do
          create(:breakdown_move, :removal, breakdown_speech: speech(zero_round, 3, kind: "justification", round: revote), actor_seat: 3)
        end

        it "warns about the round it precedes" do
          expect(timeline.warnings_for(revote)).to eq([ warning(:voting_after_removal, revote, rule: "4.4.15") ])
        end

        it "does not warn about the earlier round" do
          expect(timeline.warnings_for(main_round)).to be_empty
        end
      end

      context "when the voted-out player is removed in the farewell speech" do
        let!(:round) { vote(zero_round, "main", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 5, 8, 9, 10 ] => 3) }

        before { remove(zero_round, 5, kind: "farewell") }

        it "does not warn" do
          expect(timeline.warnings_for(round)).to be_empty
        end
      end

      context "when an already eliminated seat is removed in a speech" do
        let!(:second_day) { day(2) }

        before do
          night(1, killed: 4)
          create(:breakdown_move, :removal, breakdown_speech: speech(second_day, 1), actor_seat: 4)
          nominate(second_day, 1, 5)
        end

        let!(:round) { vote(second_day, "main", [ 1 ] => 5) }

        it "does not warn" do
          expect(timeline.warnings_for(round)).to be_empty
        end
      end
    end

    describe "lift round" do
      context "when the lift is allowed" do
        before do
          nominate(zero_round, 1, 5)
          nominate(zero_round, 2, 3)
          tie_twice(zero_round, [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3)
        end

        let!(:lift) { vote(zero_round, "lift", [ 1, 2, 3, 4, 5, 6 ] => true) }

        it "does not warn about the round" do
          expect(timeline.warnings_for(lift)).to be_empty
        end

        it "does not warn about the votes" do
          expect(lift.votes.flat_map { |ballot| timeline.warnings_for(ballot) }).to be_empty
        end
      end

      context "when the zero round has five candidates" do
        before do
          [ [ 1, 2 ], [ 3, 4 ], [ 5, 6 ], [ 7, 8 ], [ 9, 10 ] ].each { |actor, target| nominate(zero_round, actor, target) }
          tie_twice(zero_round, [ 1, 2 ] => 2, [ 3, 4 ] => 4, [ 5, 6 ] => 6, [ 7, 8 ] => 8, [ 9, 10 ] => 10)
        end

        let!(:lift) { vote(zero_round, "lift") }

        it "warns about the round" do
          expect(timeline.warnings_for(lift)).to eq([ warning(:lift_forbidden, lift, rule: "4.4.16") ])
        end
      end

      context "when a later day has five candidates with ten alive" do
        let!(:second_day) { day(2) }

        before do
          night(1)
          [ [ 1, 2 ], [ 3, 4 ], [ 5, 6 ], [ 7, 8 ], [ 9, 10 ] ].each { |actor, target| nominate(second_day, actor, target) }
          tie_twice(second_day, [ 1, 2 ] => 2, [ 3, 4 ] => 4, [ 5, 6 ] => 6, [ 7, 8 ] => 8, [ 9, 10 ] => 10)
        end

        let!(:lift) { vote(second_day, "lift") }

        it "does not warn" do
          expect(timeline.warnings_for(lift)).to be_empty
        end
      end

      context "when three candidates remain with nine alive" do
        let!(:second_day) { day(2) }

        before do
          night(1, killed: 10)
          nominate(second_day, 1, 5)
          nominate(second_day, 2, 3)
          nominate(second_day, 4, 8)
          tie_twice(second_day, [ 1, 2, 3 ] => 5, [ 4, 6, 7 ] => 3, [ 5, 8, 9 ] => 8)
        end

        let!(:lift) { vote(second_day, "lift") }

        it "warns about the round" do
          expect(timeline.warnings_for(lift)).to eq([ warning(:lift_forbidden, lift, rule: "4.4.17") ])
        end
      end

      context "when three candidates remain with ten alive" do
        before do
          nominate(zero_round, 1, 5)
          nominate(zero_round, 2, 3)
          nominate(zero_round, 4, 8)
          tie_twice(zero_round, [ 1, 2, 3 ] => 5, [ 4, 6, 7 ] => 3, [ 5, 8, 9 ] => 8, [ 10 ] => 7)
        end

        let!(:lift) { vote(zero_round, "lift") }

        it "does not warn" do
          expect(timeline.warnings_for(lift)).to be_empty
        end
      end

      context "when candidates are more than half of alive players" do
        let!(:second_day) { day(2) }

        before do
          remove(zero_round, 4, 5, 6, 7, 8, 9, 10)
          night(1)
          nominate(second_day, 1, 2)
          nominate(second_day, 2, 1)
          tie_twice(second_day, [ 1 ] => 2, [ 2 ] => 1, [ 3 ] => 3)
        end

        let!(:lift) { vote(second_day, "lift") }

        it "warns about the round" do
          expect(timeline.warnings_for(lift)).to eq([ warning(:lift_forbidden, lift, rule: "4.4.18") ])
        end
      end

      context "when candidates are exactly half of alive players" do
        let!(:second_day) { day(2) }

        before do
          remove(zero_round, 5, 6, 7, 8, 9, 10)
          night(1)
          nominate(second_day, 1, 2)
          nominate(second_day, 2, 1)
          tie_twice(second_day, [ 1 ] => 2, [ 2 ] => 1, [ 3 ] => 3, [ 4 ] => 4)
        end

        let!(:lift) { vote(second_day, "lift") }

        it "does not warn" do
          expect(timeline.warnings_for(lift)).to be_empty
        end
      end
    end

    describe "unexpected rounds" do
      before do
        nominate(zero_round, 1, 5)
        nominate(zero_round, 2, 3)
      end

      context "when a revote follows an elimination" do
        before { vote(zero_round, "main", [ 1, 2, 3, 4, 6, 7 ] => 5, [ 5, 8, 9, 10 ] => 3) }

        let!(:revote) { vote(zero_round, "revote") }

        it "warns about the round" do
          expect(timeline.warnings_for(revote)).to eq([ warning(:unexpected_vote_round, revote) ])
        end
      end

      context "when a lift round directly follows the main round tie" do
        before { vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3) }

        let!(:lift) { vote(zero_round, "lift") }

        it "warns about the round" do
          expect(timeline.warnings_for(lift)).to eq([ warning(:unexpected_vote_round, lift) ])
        end
      end

      context "when a second main round follows a tie" do
        before { vote(zero_round, "main", [ 1, 2, 3, 4, 6 ] => 5, [ 5, 7, 8, 9, 10 ] => 3) }

        let!(:second_main) { vote(zero_round, "main") }

        it "warns about the round" do
          expect(timeline.warnings_for(second_main)).to eq([ warning(:unexpected_vote_round, second_main) ])
        end
      end

      context "when a revote follows a revote tie among fewer candidates" do
        before do
          nominate(zero_round, 4, 8)
          vote(zero_round, "main", [ 1, 2, 3 ] => 5, [ 4, 6, 7 ] => 3, [ 5, 8, 9 ] => 8, [ 10 ] => 7)
          vote(zero_round, "revote", [ 1, 2, 3, 4 ] => 5, [ 5, 6, 7, 9 ] => 8, [ 8 ] => 3, [ 10 ] => 7)
        end

        let!(:second_revote) { vote(zero_round, "revote") }

        it "does not warn" do
          expect(timeline.warnings_for(second_revote)).to be_empty
        end
      end
    end

    context "when the main round has no nominees" do
      let!(:round) { vote(zero_round, "main") }

      it "warns about the round" do
        expect(timeline.warnings_for(round)).to eq([ warning(:unexpected_vote_round, round) ])
      end
    end
  end

  describe "nights" do
    context "when the night kills an eliminated seat" do
      let!(:third_night) { night(3, killed: 4) }

      before do
        night(1, killed: 4)
        day(2)
      end

      it "warns about the target" do
        expect(timeline.warnings_for(third_night)).to eq([ warning(:eliminated_target, third_night, seat: 4) ])
      end
    end

    context "when the night kills an alive seat" do
      let!(:first_night) { night(1, killed: 4) }

      it "does not warn" do
        expect(timeline.warnings_for(first_night)).to be_empty
      end
    end

    context "when the night is a miss" do
      let!(:first_night) { night(1) }

      it "does not warn" do
        expect(timeline.warnings_for(first_night)).to be_empty
      end
    end

    describe "night actions" do
      let!(:breakdown) { create(:game_breakdown, roles_mode: "open") }
      let!(:first_night) { night(1) }

      before { assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4) }

      def night_action(kind, actor: nil, target: nil)
        create(:breakdown_night_action, breakdown_phase: first_night, kind: kind, actor_seat: actor, target_seat: target)
      end

      context "when an eliminated mafia member shoots" do
        before { remove(zero_round, 1) }

        let!(:shot) { night_action("mafia_shot", actor: 1, target: 5) }

        it "warns about the shooter" do
          expect(timeline.warnings_for(shot)).to eq([ warning(:eliminated_actor, shot, seat: 1) ])
        end
      end

      context "when a shot targets an eliminated seat" do
        before { remove(zero_round, 5) }

        let!(:shot) { night_action("mafia_shot", actor: 2, target: 5) }

        it "warns about the target" do
          expect(timeline.warnings_for(shot)).to eq([ warning(:eliminated_target, shot, seat: 5) ])
        end
      end

      context "when a mafia member does not shoot" do
        let!(:shot) { night_action("mafia_shot", actor: 2) }

        it "does not warn" do
          expect(timeline.warnings_for(shot)).to be_empty
        end
      end

      context "when an eliminated don checks" do
        before { remove(zero_round, 3) }

        let!(:check) { night_action("don_check", target: 4) }

        it "warns about the checker" do
          expect(timeline.warnings_for(check)).to eq([ warning(:eliminated_checker, check, seat: 3) ])
        end
      end

      context "when an eliminated sheriff checks" do
        before { remove(zero_round, 4) }

        let!(:check) { night_action("sheriff_check", target: 1) }

        it "warns about the checker" do
          expect(timeline.warnings_for(check)).to eq([ warning(:eliminated_checker, check, seat: 4) ])
        end
      end

      context "when alive checkers check" do
        let!(:don_check) { night_action("don_check", target: 4) }
        let!(:sheriff_check) { night_action("sheriff_check", target: 1) }

        it "does not warn about the don" do
          expect(timeline.warnings_for(don_check)).to be_empty
        end

        it "does not warn about the sheriff" do
          expect(timeline.warnings_for(sheriff_check)).to be_empty
        end
      end

      context "when the don role is not assigned" do
        before { breakdown.seats.where(number: 3).update_all(role_code: "peace") }

        let!(:check) { night_action("don_check", target: 4) }

        it "does not warn about the check" do
          expect(timeline.warnings_for(check)).to be_empty
        end
      end
    end
  end

  describe "roles" do
    context "when an open breakdown has no roles" do
      let!(:breakdown) { create(:game_breakdown, roles_mode: "open") }

      it "warns about each missing role" do
        expect(timeline.warnings_for(breakdown)).to eq([
          warning(:missing_mafia, breakdown), warning(:missing_don, breakdown), warning(:missing_sheriff, breakdown)
        ])
      end
    end

    context "when an open breakdown has every role" do
      let!(:breakdown) { create(:game_breakdown, roles_mode: "open") }

      before { assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4) }

      it "does not warn" do
        expect(timeline.warnings_for(breakdown)).to be_empty
      end
    end

    context "when an open breakdown has no don" do
      let!(:breakdown) { create(:game_breakdown, roles_mode: "open") }

      before do
        assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4)
        breakdown.seats.where(number: 3).update_all(role_code: "peace")
      end

      it "warns about the don" do
        expect(timeline.warnings_for(breakdown)).to eq([ warning(:missing_don, breakdown) ])
      end
    end

    context "when a closed breakdown has no roles" do
      it "does not warn" do
        expect(timeline.warnings_for(breakdown)).to be_empty
      end
    end
  end
end
