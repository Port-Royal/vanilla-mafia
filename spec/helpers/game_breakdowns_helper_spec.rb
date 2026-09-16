require "rails_helper"

RSpec.describe GameBreakdownsHelper do
  describe "#breakdown_result_label" do
    it "translates a known result" do
      expect(helper.breakdown_result_label("city")).to eq(I18n.t("game_breakdowns.results.city"))
    end

    it "falls back to the unknown label for nil" do
      expect(helper.breakdown_result_label(nil)).to eq(I18n.t("game_breakdowns.results.unknown"))
    end

    it "falls back to the unknown label for a blank string" do
      expect(helper.breakdown_result_label("")).to eq(I18n.t("game_breakdowns.results.unknown"))
    end
  end

  describe "#breakdown_seat_names" do
    let(:breakdown) { create(:game_breakdown) }

    before { breakdown.seats.find_by(number: 2).update!(name: "Гость") }

    it "maps every seat number to its name" do
      expect(helper.breakdown_seat_names(breakdown)).to include(1 => nil, 2 => "Гость")
    end

    it "covers all ten seats" do
      expect(helper.breakdown_seat_names(breakdown).keys).to eq((1..10).to_a)
    end
  end

  describe "#breakdown_seat_label" do
    it "appends the name when present" do
      expect(helper.breakdown_seat_label({ 3 => "Гость" }, 3)).to eq("3 — Гость")
    end

    it "returns the bare number when the name is blank" do
      expect(helper.breakdown_seat_label({ 3 => "" }, 3)).to eq("3")
    end

    it "returns the bare number when the seat is unknown" do
      expect(helper.breakdown_seat_label({}, 3)).to eq("3")
    end
  end
  describe "#breakdown_move_defaults" do
    let(:breakdown) { create(:game_breakdown) }
    let(:phase) { breakdown.phases.find_by(position: 0) }
    let(:state) { GameBreakdown::Timeline.new(breakdown).state_for(phase) }
    let(:speech) { create(:breakdown_speech, breakdown_phase: phase, speaker_seat: 6) }

    it "starts a move as a plain comment" do
      expect(helper.breakdown_move_defaults(speech, state)[:kind]).to eq("other")
    end

    it "credits the move to the speaker" do
      expect(helper.breakdown_move_defaults(speech, state)[:actor_seat]).to eq(6)
    end

    it "leaves the night blank in the zero round" do
      expect(helper.breakdown_move_defaults(speech, state)[:night_number]).to be_nil
    end

    context "on a later day" do
      let!(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }
      let(:phase) { create(:breakdown_phase, game_breakdown: breakdown, position: 4) }

      before { create(:breakdown_phase, game_breakdown: breakdown, position: 2) }

      it "dates the move to the last passed night" do
        create(:breakdown_phase, game_breakdown: breakdown, position: 3, night_outcome: "miss")

        expect(helper.breakdown_move_defaults(speech, state)[:night_number]).to eq(2)
      end
    end
  end

  describe "#breakdown_move_summary" do
    let(:seat_names) { { 4 => "Гость" } }

    it "names the kind" do
      move = build(:breakdown_move, :sheriff_reveal_table, actor_seat: 1, text: nil)
      expect(helper.breakdown_move_summary(move, seat_names)).to eq(I18n.t("game_breakdowns.move_kinds.sheriff_reveal_table"))
    end

    it "appends the details after the kind" do
      move = build(:breakdown_move, :nomination, actor_seat: 1, target_seat: 4, text: nil)

      expect(helper.breakdown_move_summary(move, seat_names))
        .to eq("#{I18n.t('game_breakdowns.move_kinds.nomination')} · 4 — Гость")
    end
  end

  describe "#breakdown_move_details" do
    let(:seat_names) { { 4 => "Гость" } }

    it "is blank when the move carries nothing extra" do
      expect(helper.breakdown_move_details(build(:breakdown_move, :sheriff_reveal_table, actor_seat: 1, text: nil), seat_names)).to eq("")
    end

    it "names the target seat" do
      move = build(:breakdown_move, :nomination, actor_seat: 1, target_seat: 4, text: nil)
      expect(helper.breakdown_move_details(move, seat_names)).to eq("4 — Гость")
    end

    it "names the claimed colour and the night" do
      move = build(:breakdown_move, :check_claim, actor_seat: 1, target_seat: nil, claimed_color: "red", night_number: 2, text: nil)

      expect(helper.breakdown_move_details(move, seat_names))
        .to eq("#{I18n.t('game_breakdowns.claimed_colors.red')} · #{I18n.t('game_breakdowns.editor.night_number', number: 2)}")
    end

    it "lists the best move seats" do
      move = build(:breakdown_move, :best_move, actor_seat: 1, best_move_seats: [ 2, 4 ], text: nil)
      expect(helper.breakdown_move_details(move, seat_names)).to eq("2, 4")
    end

    it "names the removal reason" do
      move = build(:breakdown_move, :removal, actor_seat: 1, removal_reason: "fouls", text: nil)
      expect(helper.breakdown_move_details(move, seat_names)).to eq(I18n.t("game_breakdowns.removal_reasons.fouls"))
    end

    it "skips an empty comment" do
      move = build(:breakdown_move, :nomination, actor_seat: 1, target_seat: 4, text: "")
      expect(helper.breakdown_move_details(move, seat_names)).to eq("4 — Гость")
    end

    it "includes the comment" do
      move = build(:breakdown_move, actor_seat: 1, kind: "other", text: "шумел")
      expect(helper.breakdown_move_details(move, seat_names)).to eq("шумел")
    end
  end

  describe "#breakdown_tally_label" do
    let(:breakdown) { create(:game_breakdown) }
    let(:phase) { breakdown.phases.find_by(position: 0) }

    it "names the seat for a candidate round" do
      round = create(:breakdown_vote_round, breakdown_phase: phase, kind: "main", number: 1)
      expect(helper.breakdown_tally_label(round, 4, { 4 => "Гость" })).to eq("4 — Гость")
    end

    it "names the bucket for a lift round" do
      round = create(:breakdown_vote_round, breakdown_phase: phase, kind: "lift", number: 1)
      expect(helper.breakdown_tally_label(round, :for, {})).to eq(I18n.t("game_breakdowns.lift_choices.for"))
    end
  end

  describe "vote pre-filling" do
    include GameBreakdownHelpers

    let(:breakdown) { create(:game_breakdown) }
    let(:zero_round) { breakdown.phases.find_by(position: 0) }
    let(:result) { GameBreakdown::Timeline.new(breakdown).state_for(zero_round).vote_rounds.first }

    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      round
    end

    let(:round) { create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "main", number: 1) }

    describe "#breakdown_vote_value" do
      before { create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 1, candidate_seat: 4) }

      it "returns the stored choice" do
        expect(helper.breakdown_vote_value(result, 1)).to eq(4)
      end

      # 4.4.9: a player who did not vote is counted for the last nominee.
      it "falls back to the last nominee" do
        expect(helper.breakdown_vote_value(result, 3)).to eq(5)
      end
    end

    describe "#breakdown_lift_value" do
      let(:round) { create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "lift", number: 1) }

      before { create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 2, candidate_seat: nil, for_lift: false) }

      it "returns the stored choice as a string" do
        expect(helper.breakdown_lift_value(result, 2)).to eq("false")
      end

      it "is blank for a voter who did not vote" do
        expect(helper.breakdown_lift_value(result, 3)).to be_nil
      end
    end
  end

  describe "#breakdown_lift_options" do
    it "offers for and against" do
      expect(helper.breakdown_lift_options).to eq(
        [ [ I18n.t("game_breakdowns.lift_choices.for"), "true" ], [ I18n.t("game_breakdowns.lift_choices.against"), "false" ] ]
      )
    end
  end
end
