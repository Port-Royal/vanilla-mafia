require "rails_helper"

RSpec.describe BreakdownPhase, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:game_breakdown) }
    it { is_expected.to have_many(:night_actions).class_name("BreakdownNightAction").dependent(:destroy) }
    it { is_expected.to have_many(:speeches).class_name("BreakdownSpeech").order(:position).dependent(:destroy) }
    it { is_expected.to have_many(:vote_rounds).class_name("BreakdownVoteRound").order(:number).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:breakdown_phase) }

    it { is_expected.to validate_uniqueness_of(:position).scoped_to(:game_breakdown_id) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

    context "when a night ends with a kill" do
      subject { build(:breakdown_phase, :night, night_outcome: "kill", killed_seat: 1) }

      it { is_expected.to validate_numericality_of(:killed_seat).only_integer.is_in(1..10) }
    end
  end

  describe "night_outcome enum" do
    it "defines the expected mapping" do
      expect(described_class.night_outcomes).to eq("kill" => "kill", "miss" => "miss")
    end

    context "when night_outcome is unknown" do
      subject { build(:breakdown_phase, :night, night_outcome: "wound") }

      it { is_expected.to be_invalid }
    end
  end

  describe "night fields" do
    context "when a night ends with a kill and a killed seat" do
      subject { build(:breakdown_phase, :night, night_outcome: "kill", killed_seat: 4) }

      it { is_expected.to be_valid }
    end

    context "when a night ends with a kill without a killed seat" do
      subject { build(:breakdown_phase, :night, night_outcome: "kill", killed_seat: nil) }

      it { is_expected.to be_invalid }
    end

    context "when a night ends with a miss and a killed seat" do
      subject { build(:breakdown_phase, :night, night_outcome: "miss", killed_seat: 4) }

      it { is_expected.to be_invalid }
    end

    context "when a night is not filled" do
      subject { build(:breakdown_phase, :night, night_outcome: nil, killed_seat: nil) }

      it { is_expected.to be_valid }
    end

    context "when a day has a night outcome" do
      subject { build(:breakdown_phase, position: 2, night_outcome: "miss") }

      it { is_expected.to be_invalid }
    end
  end

  describe "#night? / #day? / #zero_round?" do
    context "when position is 0" do
      subject(:phase) { build(:breakdown_phase, position: 0) }

      it { is_expected.to be_day }
      it { is_expected.to be_zero_round }
      it { is_expected.not_to be_night }
    end

    context "when position is odd" do
      subject(:phase) { build(:breakdown_phase, position: 3) }

      it { is_expected.to be_night }
      it { is_expected.not_to be_day }
      it { is_expected.not_to be_zero_round }
    end

    context "when position is even and positive" do
      subject(:phase) { build(:breakdown_phase, position: 4) }

      it { is_expected.to be_day }
      it { is_expected.not_to be_night }
      it { is_expected.not_to be_zero_round }
    end

    context "when position is nil" do
      subject(:phase) { build(:breakdown_phase, position: nil) }

      it { is_expected.not_to be_day }
      it { is_expected.not_to be_night }
      it { is_expected.not_to be_zero_round }
    end
  end
end
