require "rails_helper"

RSpec.describe BreakdownSpeech, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:breakdown_phase) }
    it { is_expected.to belong_to(:breakdown_vote_round).optional }
    it { is_expected.to have_many(:moves).class_name("BreakdownMove").order(:position).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:breakdown_speech) }

    it { is_expected.to validate_numericality_of(:speaker_seat).only_integer.is_in(1..10) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "kind enum" do
    it "defines the expected mapping" do
      expect(described_class.kinds).to eq(
        "regular" => "regular",
        "farewell" => "farewell",
        "justification" => "justification"
      )
    end

    context "when kind is unknown" do
      subject { build(:breakdown_speech, kind: "toast") }

      it { is_expected.to be_invalid }
    end
  end

  describe "phase constraints" do
    context "when the phase is a night" do
      subject(:speech) { build(:breakdown_speech, breakdown_phase: build(:breakdown_phase, :night)) }

      before { speech.validate }

      it "adds a must_be_day error" do
        expect(speech.errors).to be_of_kind(:breakdown_phase, :must_be_day)
      end
    end

    context "when the phase is the zero round" do
      subject { build(:breakdown_speech, breakdown_phase: build(:breakdown_phase, position: 0)) }

      it { is_expected.to be_valid }
    end

    context "when the phase is missing" do
      subject(:speech) { build(:breakdown_speech, breakdown_phase: nil) }

      before { speech.validate }

      it "only reports the missing phase" do
        expect(speech.errors.details[:breakdown_phase]).to eq([ { error: :blank } ])
      end
    end
  end

  describe "vote round link" do
    let_it_be(:phase) { create(:breakdown_phase) }
    let_it_be(:round) { create(:breakdown_vote_round, breakdown_phase: phase, kind: "revote") }

    context "when a justification speech precedes a round of the same phase" do
      subject { build(:breakdown_speech, :justification, breakdown_phase: phase, breakdown_vote_round: round) }

      it { is_expected.to be_valid }
    end

    context "when a justification speech has no round" do
      subject(:speech) { build(:breakdown_speech, :justification, breakdown_phase: phase, breakdown_vote_round: nil) }

      before { speech.validate }

      it "adds a blank error" do
        expect(speech.errors).to be_of_kind(:breakdown_vote_round, :blank)
      end
    end

    context "when a regular speech has a round" do
      subject(:speech) { build(:breakdown_speech, breakdown_phase: phase, breakdown_vote_round: round) }

      before { speech.validate }

      it "adds a present error" do
        expect(speech.errors).to be_of_kind(:breakdown_vote_round, :present)
      end
    end

    context "when the round belongs to another phase" do
      subject(:speech) { build(:breakdown_speech, :justification, breakdown_phase: other_phase, breakdown_vote_round: round) }

      let(:other_phase) { create(:breakdown_phase, game_breakdown: phase.game_breakdown, position: 4) }

      before { speech.validate }

      it "adds a must_belong_to_phase error" do
        expect(speech.errors).to be_of_kind(:breakdown_vote_round, :must_belong_to_phase)
      end
    end
  end
end
