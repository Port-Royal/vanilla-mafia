require "rails_helper"

RSpec.describe SyncBreakdownStepsService do
  include GameBreakdownHelpers

  subject(:sync) { described_class.call(breakdown: breakdown) }

  let(:breakdown) { create(:game_breakdown) }
  let(:zero_round) { breakdown.phases.find_by(position: 0) }

  context "when nominations exist and no round was held" do
    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
    end

    it "creates the main round" do
      sync
      expect(zero_round.vote_rounds.reload.map(&:kind)).to eq([ "main" ])
    end

    it "numbers the round from one" do
      sync
      expect(zero_round.vote_rounds.reload.first.number).to eq(1)
    end

    it "is idempotent" do
      sync
      expect { described_class.call(breakdown: breakdown) }.not_to change { zero_round.vote_rounds.reload.count }
    end
  end

  context "when the zero round has a single nominee" do
    before { nominate(zero_round, 1, 4) }

    # 4.4.11: a single nominee in the zero round is not put to a vote.
    it "creates no round" do
      expect { sync }.not_to change { zero_round.vote_rounds.reload.count }
    end
  end

  context "when a day has a single nominee" do
    let(:first_day) { day(2) }

    before do
      night(1)
      nominate(first_day, 1, 4)
    end

    it "still creates the main round outside the zero round" do
      sync
      expect(first_day.vote_rounds.reload.map(&:kind)).to eq([ "main" ])
    end
  end

  context "when the main round ends in a tie" do
    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      vote(zero_round, "main", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
    end

    it "creates a revote round" do
      sync
      expect(zero_round.vote_rounds.reload.map(&:kind)).to eq([ "main", "revote" ])
    end

    it "creates justification speeches for the tied candidates in nomination order" do
      sync
      expect(zero_round.speeches.reload.select(&:justification?).map(&:speaker_seat)).to eq([ 4, 5 ])
    end

    it "points the justification speeches at the revote round" do
      sync
      revote = zero_round.vote_rounds.reload.find_by(kind: "revote")

      expect(zero_round.speeches.reload.select(&:justification?).map(&:breakdown_vote_round_id).uniq).to eq([ revote.id ])
    end

    it "is idempotent" do
      sync
      expect { described_class.call(breakdown: breakdown) }.not_to change { zero_round.speeches.reload.count }
    end
  end

  context "when an earlier round was deleted and the numbers have a gap" do
    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      vote(zero_round, "main", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
      create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "revote", number: 7).destroy!
      zero_round.vote_rounds.reload
    end

    it "numbers the new round after the highest existing one" do
      sync
      expect(zero_round.vote_rounds.reload.map(&:number)).to eq([ 1, 2 ])
    end
  end

  # Deleting a middle round leaves a gap, so the next number must follow the highest one, not the count.
  context "when a middle round was deleted and the last one ties again" do
    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      vote(zero_round, "main", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
      revote = create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "revote", number: 3)
      [ 1, 2, 3, 4, 5 ].each { |seat| create(:breakdown_vote, breakdown_vote_round: revote, voter_seat: seat, candidate_seat: 4) }
      [ 6, 7, 8, 9, 10 ].each { |seat| create(:breakdown_vote, breakdown_vote_round: revote, voter_seat: seat, candidate_seat: 5) }
      zero_round.vote_rounds.reload
    end

    it "creates the lift round after the highest number" do
      sync
      expect(zero_round.vote_rounds.reload.map(&:number)).to eq([ 1, 3, 4 ])
    end

    it "creates the lift round" do
      sync
      expect(zero_round.vote_rounds.reload.map(&:kind)).to eq([ "main", "revote", "lift" ])
    end
  end

  context "when a revote ties among all of its candidates" do
    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      vote(zero_round, "main", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
      vote(zero_round, "revote", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
    end

    it "creates a lift round" do
      sync
      expect(zero_round.vote_rounds.reload.map(&:kind)).to eq([ "main", "revote", "lift" ])
    end

    it "creates no speeches before the lift" do
      expect { sync }.not_to change { zero_round.speeches.reload.count }
    end
  end

  context "when a seat is voted out" do
    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      vote(zero_round, "main", [ 1, 2, 3, 4, 5, 6 ] => 4, [ 7, 8, 9, 10 ] => 5)
    end

    it "creates the farewell speech of the eliminated seat" do
      sync
      expect(zero_round.speeches.reload.select(&:farewell?).map(&:speaker_seat)).to eq([ 4 ])
    end

    it "appends it after the existing speeches" do
      sync
      farewell, regular = zero_round.speeches.reload.partition(&:farewell?)

      expect(farewell.first.position).to be > regular.map(&:position).max
    end

    it "is idempotent" do
      sync
      expect { described_class.call(breakdown: breakdown) }.not_to change { zero_round.speeches.reload.count }
    end
  end

  context "when a lift passes" do
    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      vote(zero_round, "main", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
      vote(zero_round, "revote", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
      vote(zero_round, "lift", (1..8).to_a => true, [ 9, 10 ] => false)
    end

    it "creates a farewell speech for every lifted candidate" do
      sync
      expect(zero_round.speeches.reload.select(&:farewell?).map(&:speaker_seat)).to eq([ 4, 5 ])
    end
  end

  context "when the day's voting was cancelled by a removal" do
    before do
      nominate(zero_round, 1, 4)
      remove(zero_round, 7)
    end

    it "creates no round" do
      expect { sync }.not_to change { zero_round.vote_rounds.reload.count }
    end
  end

  context "when a later phase gains a step from an earlier correction" do
    let(:first_day) { day(2) }

    before do
      night(1, killed: 3)
      nominate(first_day, 1, 4)
    end

    it "creates the round in that later phase too" do
      sync
      expect(first_day.vote_rounds.reload.map(&:kind)).to eq([ "main" ])
    end
  end

  context "when a step cannot be fully created" do
    let(:step) { GameBreakdown::Timeline::ExpectedStep.new(kind: :revote_round, seats: [ 99 ]) }
    let(:state) { instance_double(GameBreakdown::Timeline::PhaseState, phase: zero_round, expected_steps: [ step ]) }

    before do
      allow(GameBreakdown::Timeline).to receive(:new).and_return(instance_double(GameBreakdown::Timeline, phases: [ state ]))
    end

    it "raises" do
      expect { sync }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "rolls the round back with the speeches" do
      expect { suppress(ActiveRecord::RecordInvalid) { sync } }.not_to change { zero_round.vote_rounds.reload.count }
    end
  end

  context "when the phase has no speeches yet" do
    let(:step) { GameBreakdown::Timeline::ExpectedStep.new(kind: :farewell_speeches, seats: [ 4 ]) }
    let(:state) { instance_double(GameBreakdown::Timeline::PhaseState, phase: zero_round, expected_steps: [ step ]) }

    before do
      zero_round.speeches.delete_all
      allow(GameBreakdown::Timeline).to receive(:new).and_return(instance_double(GameBreakdown::Timeline, phases: [ state ]))
    end

    it "numbers the first speech from zero" do
      sync
      expect(zero_round.speeches.reload.map(&:position)).to eq([ 0 ])
    end
  end

  context "when nothing is expected" do
    before { breakdown }

    it "creates no rounds" do
      expect { sync }.not_to change(BreakdownVoteRound, :count)
    end

    it "creates no speeches" do
      expect { sync }.not_to change(BreakdownSpeech, :count)
    end
  end
end
