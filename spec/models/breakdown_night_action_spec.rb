require "rails_helper"

RSpec.describe BreakdownNightAction, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:breakdown_phase) }
  end

  describe "validations" do
    subject { build(:breakdown_night_action) }

    it { is_expected.to validate_numericality_of(:actor_seat).only_integer.is_in(1..10).allow_nil }
    it { is_expected.to validate_numericality_of(:target_seat).only_integer.is_in(1..10).allow_nil }
  end

  describe "tactical miss" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

    context "when a mafia shot has no target" do
      subject { build(:breakdown_night_action, breakdown_phase: night, kind: "mafia_shot", actor_seat: 2, target_seat: nil, tactical_miss: true) }

      it { is_expected.to be_valid }
    end

    context "when a mafia shot also has a target" do
      subject(:action) { build(:breakdown_night_action, breakdown_phase: night, kind: "mafia_shot", actor_seat: 2, target_seat: 7, tactical_miss: true) }

      before { action.validate }

      it "is refused" do
        expect(action.errors).to be_of_kind(:tactical_miss, :invalid)
      end
    end

    context "when the action is a check" do
      subject(:action) { build(:breakdown_night_action, breakdown_phase: night, kind: "don_check", target_seat: nil, tactical_miss: true) }

      before { action.validate }

      it "is refused" do
        expect(action.errors).to be_of_kind(:tactical_miss, :invalid)
      end
    end

    it "is off by default" do
      expect(described_class.new.tactical_miss).to be false
    end
  end

  describe "kind enum" do
    it "defines the expected mapping" do
      expect(described_class.kinds).to eq(
        "mafia_shot" => "mafia_shot",
        "don_check" => "don_check",
        "sheriff_check" => "sheriff_check"
      )
    end

    context "when kind is unknown" do
      subject { build(:breakdown_night_action, kind: "doctor_heal") }

      it { is_expected.to be_invalid }
    end
  end

  describe "phase constraints" do
    context "when the phase is a night of an open breakdown" do
      subject { build(:breakdown_night_action) }

      it { is_expected.to be_valid }
    end

    context "when the phase is a day" do
      subject(:action) { build(:breakdown_night_action, breakdown_phase: build(:breakdown_phase, position: 2)) }

      before { action.validate }

      it "adds a must_be_night error" do
        expect(action.errors).to be_of_kind(:breakdown_phase, :must_be_night)
      end
    end

    context "when the breakdown has closed roles" do
      subject(:action) { build(:breakdown_night_action, breakdown_phase: phase) }

      let(:phase) { build(:breakdown_phase, :night, game_breakdown: build(:game_breakdown, roles_mode: "closed")) }

      before { action.validate }

      it "adds a must_be_open_roles_mode error" do
        expect(action.errors).to be_of_kind(:breakdown_phase, :must_be_open_roles_mode)
      end
    end

    context "when the phase is missing" do
      subject(:action) { build(:breakdown_night_action, breakdown_phase: nil) }

      before { action.validate }

      it "only reports the missing phase" do
        expect(action.errors.details[:breakdown_phase]).to eq([ { error: :blank } ])
      end
    end
  end
end
