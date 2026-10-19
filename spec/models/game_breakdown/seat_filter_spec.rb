require "rails_helper"

RSpec.describe GameBreakdown::SeatFilter do
  include GameBreakdownHelpers

  subject(:filter) { described_class.for(breakdown, seat_param) }

  let!(:breakdown) { create(:game_breakdown, roles_mode: "open") }
  let(:zero_round) { breakdown.phases.find_by!(position: 0) }
  let(:timeline) { GameBreakdown::Timeline.new(breakdown) }
  let(:zero_round_state) { timeline.state_for(zero_round) }
  let(:seat_param) { "3" }

  describe ".for" do
    it "filters by a valid seat" do
      expect(filter.seat).to eq(3)
    end

    %w[0 11 abc].push(nil, "").each do |value|
      context "with #{value.inspect}" do
        let(:seat_param) { value }

        it "falls back to the unfiltered view" do
          expect(filter.seat).to be_nil
        end
      end
    end
  end

  describe "speeches and moves" do
    let!(:own_speech) { speech(zero_round, 3) }
    let!(:own_move) { create(:breakdown_move, :nomination, breakdown_speech: own_speech, actor_seat: 3, target_seat: 7) }
    let!(:foul_in_own_speech) { create(:breakdown_move, :foul, breakdown_speech: own_speech, actor_seat: 8) }
    let!(:other_speech) { speech(zero_round, 5) }
    let!(:unrelated_move) { create(:breakdown_move, :nomination, breakdown_speech: other_speech, actor_seat: 5, target_seat: 7) }
    let!(:move_by_seat_elsewhere) { create(:breakdown_move, :foul, breakdown_speech: other_speech, actor_seat: 3) }
    let!(:move_about_seat) { create(:breakdown_move, :check_request, breakdown_speech: other_speech, actor_seat: 5, target_seat: 3) }
    let!(:best_move_naming_seat) { create(:breakdown_move, :best_move, breakdown_speech: other_speech, actor_seat: 5, best_move_seats: [ 1, 3 ]) }
    let!(:quiet_speech) { speech(zero_round, 9) }

    it "keeps the player's own speech and speeches with a move involving them" do
      expect(filter.speeches([ own_speech, other_speech, quiet_speech ])).to eq([ own_speech, other_speech ])
    end

    it "shows every move of the player's own speech" do
      expect(filter.speech_moves(own_speech)).to eq([ own_move, foul_in_own_speech ])
    end

    it "shows only the moves involving the player in someone else's speech" do
      expect(filter.speech_moves(other_speech)).to eq([ move_by_seat_elsewhere, move_about_seat, best_move_naming_seat ])
    end

    context "without a seat" do
      let(:seat_param) { nil }

      it "keeps every speech" do
        expect(filter.speeches([ own_speech, other_speech, quiet_speech ])).to eq([ own_speech, other_speech, quiet_speech ])
      end

      it "keeps every move" do
        expect(filter.speech_moves(other_speech)).to eq(other_speech.moves.to_a)
      end
    end
  end

  describe "vote rounds" do
    let(:main) { zero_round_state.vote_rounds.first }

    before do
      nominate(zero_round, 1, 3)
      nominate(zero_round, 2, 6)
    end

    context "when the player is a candidate and votes" do
      before { vote(zero_round, "main", [ 1, 2, 3, 4 ] => 6, [ 5, 7, 8, 9, 10 ] => 3, [ 6 ] => 3) }

      it "keeps the row of votes for them and the row with their own vote" do
        expect(filter.tally(main)).to eq(6 => [ 1, 2, 3, 4 ], 3 => [ 5, 6, 7, 8, 9, 10 ])
      end

      it "keeps the round" do
        expect(filter.rounds(zero_round_state.vote_rounds)).to eq([ main ])
      end
    end

    context "when the player only votes" do
      let(:seat_param) { "9" }

      before { vote(zero_round, "main", [ 1, 2, 3, 4, 9 ] => 6, [ 5, 6, 7, 8, 10 ] => 3) }

      it "keeps only the row with their vote" do
        expect(filter.tally(main)).to eq(6 => [ 1, 2, 3, 4, 9 ])
      end
    end

    context "when the player has nothing to do with the round" do
      let(:seat_param) { "9" }

      before { vote(zero_round, "main", [ 1, 2, 3, 4 ] => 6, [ 5, 6, 7, 8, 10 ] => 3) }

      it "drops the round" do
        expect(filter.rounds(zero_round_state.vote_rounds)).to be_empty
      end
    end

    context "when the player made a move in the round" do
      let(:seat_param) { "9" }
      let!(:round) { vote(zero_round, "main", [ 1, 2, 3, 4 ] => 6, [ 5, 6, 7, 8, 10 ] => 3) }
      let!(:round_foul) { create(:breakdown_move, :foul, :in_vote_round, breakdown_vote_round: round, actor_seat: 9) }

      before { create(:breakdown_move, :foul, :in_vote_round, breakdown_vote_round: round, actor_seat: 2) }

      it "keeps the round with only their move" do
        expect([ filter.rounds(zero_round_state.vote_rounds), filter.round_moves(round) ]).to eq([ [ main ], [ round_foul ] ])
      end
    end

    context "when the player is a lift candidate" do
      before do
        vote(zero_round, "main", (1..5).to_a => 3, (6..10).to_a => 6)
        vote(zero_round, "revote", (1..5).to_a => 3, (6..10).to_a => 6)
        vote(zero_round, "lift", [ 1, 2, 4, 5, 7, 8 ] => true)
      end

      it "keeps the whole lift tally" do
        expect(filter.tally(zero_round_state.vote_rounds.third)).to eq(for: [ 1, 2, 4, 5, 7, 8 ])
      end
    end
  end

  describe "nights" do
    let!(:first_night) { night(1) }
    let(:first_night_state) { timeline.state_for(first_night) }

    before { assign_roles(mafia: [ 1, 2 ], don: 3, sheriff: 4) }

    def action(kind, actor: nil, target: nil)
      create(:breakdown_night_action, breakdown_phase: first_night, kind: kind, actor_seat: actor, target_seat: target)
    end

    context "when the player is killed" do
      before { first_night.update!(night_outcome: "kill", killed_seat: 3) }

      it "shows the kill" do
        expect(filter.night_outcome?(first_night)).to be true
      end

      it "keeps the night" do
        expect(filter.phase?(first_night_state)).to be true
      end
    end

    context "when someone else is killed" do
      before { first_night.update!(night_outcome: "kill", killed_seat: 7) }

      it "hides the kill and the night" do
        expect([ filter.night_outcome?(first_night), filter.phase?(first_night_state) ]).to eq([ false, false ])
      end
    end

    context "with shots and checks on a miss" do
      let!(:shot_at_player) { action("mafia_shot", actor: 1, target: 3) }
      let!(:don_check) { action("don_check", target: 4) }
      let!(:sheriff_check_of_player) { action("sheriff_check", target: 3) }

      before { action("mafia_shot", actor: 2, target: 7) }

      it "keeps the shot at them, their own check as the don and the check of them" do
        expect(filter.night_actions(first_night)).to eq([ shot_at_player, don_check, sheriff_check_of_player ])
      end
    end

    context "when the player shoots" do
      let(:seat_param) { "2" }
      let!(:own_shot) { action("mafia_shot", actor: 2, target: nil) }

      before { action("mafia_shot", actor: 1, target: 7) }

      it "keeps their shot" do
        expect(filter.night_actions(first_night)).to eq([ own_shot ])
      end
    end
  end

  describe "#phase?" do
    let!(:second_day) { day(2) }

    before do
      night(1)
      speech(zero_round, 3)
      speech(second_day, 5)
    end

    it "keeps a day where the player spoke" do
      expect(filter.phase?(zero_round_state)).to be true
    end

    it "hides a day with nothing of the player" do
      expect(filter.phase?(timeline.state_for(second_day))).to be false
    end

    context "without a seat" do
      let(:seat_param) { nil }

      it "keeps every phase" do
        expect(timeline.phases.map { |state| filter.phase?(state) }).to all(be true)
      end
    end
  end
end
