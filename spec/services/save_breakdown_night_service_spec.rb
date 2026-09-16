require "rails_helper"

RSpec.describe SaveBreakdownNightService do
  subject(:save) { described_class.call(phase: phase, shots: shots, checks: checks) }

  let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
  let(:phase) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }
  let(:shots) { {} }
  let(:checks) { {} }

  describe "mafia shots" do
    context "with a target" do
      let(:shots) { { "3" => "7" } }

      it "records the shot" do
        save
        expect(phase.night_actions.reload.map { |a| [ a.kind, a.actor_seat, a.target_seat ] }).to eq([ [ "mafia_shot", 3, 7 ] ])
      end
    end

    context "with the did-not-shoot marker" do
      let(:shots) { { "3" => described_class::NO_SHOT } }

      it "records a shot with no target" do
        save
        expect(phase.night_actions.reload.map { |a| [ a.kind, a.actor_seat, a.target_seat ] }).to eq([ [ "mafia_shot", 3, nil ] ])
      end
    end

    context "with a blank choice" do
      let(:shots) { { "3" => "" } }

      it "records nothing" do
        expect { save }.not_to change { phase.night_actions.reload.count }
      end

      it "removes a shot recorded earlier" do
        create(:breakdown_night_action, breakdown_phase: phase, kind: "mafia_shot", actor_seat: 3, target_seat: 7)

        expect { save }.to change { phase.night_actions.reload.count }.by(-1)
      end
    end

    context "with a changed target" do
      let(:shots) { { "3" => "8" } }

      before { create(:breakdown_night_action, breakdown_phase: phase, kind: "mafia_shot", actor_seat: 3, target_seat: 7) }

      it "updates the existing shot" do
        save
        expect(phase.night_actions.reload.map(&:target_seat)).to eq([ 8 ])
      end

      it "creates no second shot for the same shooter" do
        expect { save }.not_to change { phase.night_actions.reload.count }
      end
    end

    context "with several shooters" do
      let(:shots) { { "3" => "7", "5" => "7", "9" => described_class::NO_SHOT } }

      it "records one row per shooter" do
        save
        expect(phase.night_actions.reload.map(&:actor_seat)).to contain_exactly(3, 5, 9)
      end
    end

    context "with a target outside the table" do
      let(:shots) { { "3" => "11" } }

      it "records nothing" do
        expect { save }.not_to change { phase.night_actions.reload.count }
      end
    end
  end

  describe "checks" do
    context "with both checks" do
      let(:checks) { { "don_check" => "7", "sheriff_check" => "2" } }

      it "records one row per check" do
        save
        expect(phase.night_actions.reload.map { |a| [ a.kind, a.target_seat ] })
          .to contain_exactly([ "don_check", 7 ], [ "sheriff_check", 2 ])
      end

      it "leaves the actor implied by the role" do
        save
        expect(phase.night_actions.reload.map(&:actor_seat).uniq).to eq([ nil ])
      end
    end

    context "with a changed target" do
      let(:checks) { { "don_check" => "8" } }

      before { create(:breakdown_night_action, breakdown_phase: phase, kind: "don_check", actor_seat: nil, target_seat: 7) }

      it "updates the existing check" do
        save
        expect(phase.night_actions.reload.map(&:target_seat)).to eq([ 8 ])
      end
    end

    context "with a blank choice" do
      let(:checks) { { "don_check" => "" } }

      it "removes a check recorded earlier" do
        create(:breakdown_night_action, breakdown_phase: phase, kind: "don_check", actor_seat: nil, target_seat: 7)

        expect { save }.to change { phase.night_actions.reload.count }.by(-1)
      end
    end

    context "with an unknown kind" do
      let(:checks) { { "mafia_shot" => "7" } }

      it "records nothing" do
        expect { save }.not_to change { phase.night_actions.reload.count }
      end
    end
  end

  # Shots belong to a miss: a kill already says who the mafia hit.
  describe "shots against a kill" do
    let(:phase) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "kill", killed_seat: 4) }

    context "with shots left from an earlier miss" do
      before { create(:breakdown_night_action, breakdown_phase: phase, kind: "mafia_shot", actor_seat: 3, target_seat: 7) }

      it "drops them" do
        expect { save }.to change { phase.night_actions.reload.count }.by(-1)
      end

      it "keeps the checks" do
        create(:breakdown_night_action, breakdown_phase: phase, kind: "don_check", actor_seat: nil, target_seat: 5)

        save

        expect(phase.night_actions.reload.map(&:kind)).to eq([ "don_check" ])
      end
    end

    context "with shots submitted anyway" do
      let(:shots) { { "3" => "7" } }

      it "records none" do
        expect { save }.not_to change { phase.night_actions.reload.count }
      end
    end

    context "with a check submitted" do
      let(:checks) { { "don_check" => "5" } }

      it "records it" do
        save
        expect(phase.night_actions.reload.map(&:kind)).to eq([ "don_check" ])
      end
    end
  end

  describe "shots against a night with no recorded outcome" do
    let(:phase) { create(:breakdown_phase, game_breakdown: breakdown, position: 1) }
    let(:shots) { { "3" => "7" } }

    it "records none" do
      expect { save }.not_to change { phase.night_actions.reload.count }
    end
  end

  context "when the breakdown hides the roles" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "closed") }
    let(:shots) { { "3" => "7" } }
    let(:checks) { { "don_check" => "7" } }

    # Night internals only exist in open roles mode; in closed mode the morning outcome is all that is known.
    it "records nothing" do
      expect { save }.not_to change { phase.night_actions.reload.count }
    end
  end

  context "when the phase is a day" do
    let(:phase) { create(:breakdown_phase, game_breakdown: breakdown, position: 2) }
    let(:shots) { { "3" => "7" } }

    it "records nothing" do
      expect { save }.not_to change { phase.night_actions.reload.count }
    end
  end
end
