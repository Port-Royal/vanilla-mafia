require "rails_helper"

RSpec.describe BreakdownVoteRound, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:breakdown_phase) }
    it { is_expected.to have_many(:votes).class_name("BreakdownVote").dependent(:destroy) }
    it { is_expected.to have_many(:moves).class_name("BreakdownMove").order(:position).dependent(:destroy) }
    it { is_expected.to have_many(:justification_speeches).class_name("BreakdownSpeech").dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:breakdown_vote_round) }

    it { is_expected.to validate_uniqueness_of(:number).scoped_to(:breakdown_phase_id) }
    it { is_expected.to validate_numericality_of(:number).only_integer.is_greater_than(0) }
  end

  describe "kind enum" do
    it "defines the expected mapping" do
      expect(described_class.kinds).to eq("main" => "main", "revote" => "revote", "lift" => "lift")
    end

    context "when kind is unknown" do
      subject { build(:breakdown_vote_round, kind: "popular") }

      it { is_expected.to be_invalid }
    end
  end

  describe "phase constraints" do
    context "when the phase is a day" do
      subject { build(:breakdown_vote_round) }

      it { is_expected.to be_valid }
    end

    context "when the phase is a night" do
      subject(:round) { build(:breakdown_vote_round, breakdown_phase: build(:breakdown_phase, :night)) }

      before { round.validate }

      it "adds a must_be_day error" do
        expect(round.errors).to be_of_kind(:breakdown_phase, :must_be_day)
      end
    end

    context "when the phase is missing" do
      subject(:round) { build(:breakdown_vote_round, breakdown_phase: nil) }

      before { round.validate }

      it "only reports the missing phase" do
        expect(round.errors.details[:breakdown_phase]).to eq([ { error: :blank } ])
      end
    end
  end
  describe "#move_actor_seat" do
    it "is blank" do
      expect(build(:breakdown_vote_round).move_actor_seat).to be_nil
    end
  end

  describe "#move_context_param" do
    let(:round) { create(:breakdown_vote_round) }

    it "addresses the round" do
      expect(round.move_context_param).to eq(vote_round_id: round.id)
    end
  end
end
