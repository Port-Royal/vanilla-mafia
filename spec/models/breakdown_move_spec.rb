require "rails_helper"

RSpec.describe BreakdownMove, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:breakdown_speech).optional }
    it { is_expected.to belong_to(:breakdown_vote_round).optional }
  end

  describe "validations" do
    subject { build(:breakdown_move) }

    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:target_seat).only_integer.is_in(1..10).allow_nil }
    it { is_expected.to validate_numericality_of(:night_number).only_integer.is_greater_than(0).allow_nil }
  end

  describe "enums" do
    it "defines the move kind catalogue" do
      expect(described_class.kinds.keys).to eq(%w[
        sheriff_reveal_table sheriff_reveal_to_player check_claim nomination check_request
        split_break protection best_move removal other
      ])
    end

    it "stores kinds as strings" do
      expect(described_class.kinds.values).to eq(described_class.kinds.keys)
    end

    it "defines claimed colors" do
      expect(described_class.claimed_colors).to eq("red" => "red", "black" => "black")
    end

    it "defines removal reasons" do
      expect(described_class.removal_reasons).to eq(
        "fouls" => "fouls",
        "technical_fouls" => "technical_fouls",
        "disqualification" => "disqualification"
      )
    end

    it "exposes prefixed claimed color predicates" do
      expect(described_class.new(claimed_color: "red")).to be_claimed_color_red
    end

    it "exposes prefixed removal reason predicates" do
      expect(described_class.new(removal_reason: "fouls")).to be_removal_reason_fouls
    end

    context "when kind is unknown" do
      subject { build(:breakdown_move, kind: "dance") }

      it { is_expected.to be_invalid }
    end

    context "when claimed_color is unknown" do
      subject { build(:breakdown_move, claimed_color: "green") }

      it { is_expected.to be_invalid }
    end

    context "when removal_reason is unknown" do
      subject { build(:breakdown_move, removal_reason: "boredom") }

      it { is_expected.to be_invalid }
    end
  end

  describe "context" do
    let_it_be(:speech) { create(:breakdown_speech) }
    let_it_be(:round) { create(:breakdown_vote_round) }

    context "when attached to a speech" do
      subject { build(:breakdown_move, breakdown_speech: speech, breakdown_vote_round: nil) }

      it { is_expected.to be_valid }
    end

    context "when attached to a vote round" do
      subject { build(:breakdown_move, breakdown_speech: nil, breakdown_vote_round: round) }

      it { is_expected.to be_valid }
    end

    context "when attached to both" do
      subject(:move) { build(:breakdown_move, breakdown_speech: speech, breakdown_vote_round: round) }

      before { move.validate }

      it "adds an exactly_one_context error" do
        expect(move.errors).to be_of_kind(:base, :exactly_one_context)
      end
    end

    context "when attached to neither" do
      subject(:move) { build(:breakdown_move, breakdown_speech: nil, breakdown_vote_round: nil, actor_seat: 1) }

      before { move.validate }

      it "adds an exactly_one_context error" do
        expect(move.errors).to be_of_kind(:base, :exactly_one_context)
      end
    end
  end

  describe "actor seat" do
    let_it_be(:speech) { create(:breakdown_speech, speaker_seat: 7) }

    context "when actor seat is not given in a speech" do
      subject(:move) { build(:breakdown_move, breakdown_speech: speech, actor_seat: nil) }

      before { move.validate }

      it "defaults to the speaker" do
        expect(move.actor_seat).to eq(7)
      end
    end

    context "when actor seat is given in a speech" do
      subject(:move) { build(:breakdown_move, breakdown_speech: speech, actor_seat: 2) }

      before { move.validate }

      it "keeps the given actor" do
        expect(move.actor_seat).to eq(2)
      end
    end

    context "when actor seat is not given in a vote round" do
      subject(:move) { build(:breakdown_move, :in_vote_round, actor_seat: nil) }

      before { move.validate }

      it "adds a not_a_number error" do
        expect(move.errors).to be_of_kind(:actor_seat, :not_a_number)
      end
    end

    context "when actor seat is out of range" do
      subject(:move) { build(:breakdown_move, :in_vote_round, actor_seat: 11) }

      before { move.validate }

      it "adds an in error" do
        expect(move.errors).to be_of_kind(:actor_seat, :in)
      end
    end

    context "when actor seat is not an integer" do
      subject(:move) { build(:breakdown_move, :in_vote_round, actor_seat: 1.5) }

      before { move.validate }

      it "adds a not_an_integer error" do
        expect(move.errors).to be_of_kind(:actor_seat, :not_an_integer)
      end
    end
  end

  describe "kind-specific required fields" do
    {
      "sheriff_reveal_table" => [],
      "sheriff_reveal_to_player" => %i[target_seat],
      "check_claim" => %i[claimed_color night_number],
      "nomination" => %i[target_seat],
      "check_request" => %i[target_seat],
      "split_break" => [],
      "protection" => %i[target_seat],
      "best_move" => %i[best_move_seats],
      "removal" => %i[removal_reason],
      "other" => %i[text]
    }.each do |kind, required|
      context "when kind is #{kind} with no optional fields" do
        subject(:move) { build(:breakdown_move, kind: kind, text: nil) }

        before { move.validate }

        it "requires exactly #{required.empty? ? 'nothing' : required.join(', ')}" do
          blank_attributes = move.errors.details.select { |_, details| details.include?(error: :blank) }.keys
          expect(blank_attributes).to match_array(required)
        end
      end
    end

    context "when a check claim has a color, night and no target" do
      subject { build(:breakdown_move, kind: "check_claim", claimed_color: "black", night_number: 1, target_seat: nil) }

      it { is_expected.to be_valid }
    end

    context "when an other move has text" do
      subject { build(:breakdown_move, kind: "other", text: "поднял руку") }

      it { is_expected.to be_valid }
    end
  end

  describe "best move seats" do
    context "with three distinct seats" do
      subject { build(:breakdown_move, :best_move, best_move_seats: [ 1, 5, 10 ]) }

      it { is_expected.to be_valid }
    end

    context "with one seat" do
      subject { build(:breakdown_move, :best_move, best_move_seats: [ 3 ]) }

      it { is_expected.to be_valid }
    end

    {
      "more than three seats" => [ 1, 2, 3, 4 ],
      "an empty list" => [],
      "duplicate seats" => [ 2, 2 ],
      "seats out of range" => [ 0, 11 ],
      "a valid seat mixed with one out of range" => [ 3, 11 ],
      "a non-integer seat" => [ "3" ],
      "a non-array value" => 3
    }.each do |description, seats|
      context "with #{description}" do
        subject(:move) { build(:breakdown_move, kind: "other", best_move_seats: seats) }

        before { move.validate }

        it "adds an invalid error" do
          expect(move.errors).to be_of_kind(:best_move_seats, :invalid)
        end
      end
    end

    context "when not given" do
      subject(:move) { build(:breakdown_move, kind: "other", best_move_seats: nil) }

      it { is_expected.to be_valid }
    end
  end
end
