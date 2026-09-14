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
