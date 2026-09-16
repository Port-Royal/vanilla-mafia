require "rails_helper"

RSpec.describe AppendBreakdownPhaseService do
  include GameBreakdownHelpers

  subject(:append) { described_class.call(breakdown: breakdown) }

  let(:breakdown) { create(:game_breakdown) }

  context "when the last phase is the zero round" do
    it "creates the first night" do
      expect(append).to have_attributes(position: 1, night_outcome: nil)
    end

    it "leaves the night empty" do
      expect(append.speeches).to be_empty
    end

    it "appends the phase to the breakdown" do
      append
      expect(breakdown.phases.reload.map(&:position)).to eq([ 0, 1 ])
    end
  end

  context "when the last phase is a night with a kill" do
    before { night(1, killed: 7) }

    it "creates the next day" do
      expect(append).to have_attributes(position: 2)
    end

    it "opens the day with the farewell speech of the killed seat" do
      expect(append.speeches.first).to have_attributes(speaker_seat: 7, kind: "farewell", position: 0)
    end

    it "follows with regular speeches of the alive seats in speech order" do
      expect(append.speeches.drop(1).map(&:speaker_seat)).to eq([ 2, 3, 4, 5, 6, 8, 9, 10, 1 ])
    end

    it "marks every speech after the farewell as regular" do
      expect(append.speeches.drop(1).map(&:kind).uniq).to eq([ "regular" ])
    end

    it "numbers the speeches from zero without gaps" do
      expect(append.speeches.map(&:position)).to eq((0..9).to_a)
    end
  end

  context "when the last phase is a night with a miss" do
    before { night(1) }

    it "creates no farewell speech" do
      expect(append.speeches.map(&:kind).uniq).to eq([ "regular" ])
    end

    it "creates a speech for every seat" do
      expect(append.speeches.map(&:speaker_seat)).to eq([ 2, 3, 4, 5, 6, 7, 8, 9, 10, 1 ])
    end
  end

  context "when the previous day already shifted the starter" do
    before do
      night(1)
      day(2)
      night(3)
    end

    it "starts the next day at the seat after the previous day's starter" do
      expect(append.speeches.first.speaker_seat).to eq(3)
    end
  end

  context "when a speech cannot be created" do
    let(:step) do
      GameBreakdown::Timeline::NextPhase.new(position: 2, kind: :day, farewell_seat: nil, speech_order: [ 1, 99 ])
    end

    before do
      allow(GameBreakdown::Timeline).to receive(:new).and_return(instance_double(GameBreakdown::Timeline, next_phase: step))
    end

    it "raises" do
      expect { append }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "rolls the phase back" do
      expect { suppress(ActiveRecord::RecordInvalid) { append } }.not_to change { breakdown.phases.reload.count }
    end

    it "rolls the speeches back" do
      suppress(ActiveRecord::RecordInvalid) { append }
      expect(BreakdownSpeech.count).to eq(0)
    end
  end

  context "when the game is already over" do
    before do
      %w[peace mafia].each { |code| Role.find_or_create_by!(code: code) { |role| role.name = code } }
      breakdown.seats.update_all(role_code: "peace")
    end

    it "returns nil" do
      expect(append).to be_nil
    end

    it "creates no phase" do
      expect { append }.not_to change { breakdown.phases.reload.count }
    end
  end
end
