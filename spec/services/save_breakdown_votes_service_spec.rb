require "rails_helper"

RSpec.describe SaveBreakdownVotesService do
  subject(:save) { described_class.call(round: round, ballots: ballots) }

  let(:breakdown) { create(:game_breakdown) }
  let(:phase) { breakdown.phases.find_by(position: 0) }

  describe "a candidate round" do
    let(:round) { create(:breakdown_vote_round, breakdown_phase: phase, kind: "main", number: 1) }

    context "with new ballots" do
      let(:ballots) { { "1" => { "candidate_seat" => "4" }, "2" => { "candidate_seat" => "5" } } }

      it "creates a vote per voter" do
        expect { save }.to change { round.votes.reload.count }.by(2)
      end

      it "stores the chosen candidates" do
        save
        expect(round.votes.reload.map { |vote| [ vote.voter_seat, vote.candidate_seat ] }).to contain_exactly([ 1, 4 ], [ 2, 5 ])
      end

      it "leaves for_lift unset" do
        save
        expect(round.votes.reload.map(&:for_lift).uniq).to eq([ nil ])
      end
    end

    context "with a changed ballot" do
      let(:ballots) { { "1" => { "candidate_seat" => "5" } } }

      before { create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 1, candidate_seat: 4) }

      it "updates the existing vote" do
        save
        expect(round.votes.reload.map(&:candidate_seat)).to eq([ 5 ])
      end

      it "creates no second vote for the same voter" do
        expect { save }.not_to change { round.votes.reload.count }
      end
    end

    context "with a cleared ballot" do
      let(:ballots) { { "1" => { "candidate_seat" => "" } } }

      before { create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 1, candidate_seat: 4) }

      it "removes the vote" do
        expect { save }.to change { round.votes.reload.count }.by(-1)
      end
    end

    context "with a cleared ballot for a voter who never voted" do
      let(:ballots) { { "3" => { "candidate_seat" => "" } } }

      it "creates nothing" do
        expect { save }.not_to change { round.votes.reload.count }
      end
    end

    context "with an invalid candidate" do
      let(:ballots) { { "1" => { "candidate_seat" => "11" } } }

      it "stores no vote" do
        expect { save }.not_to change { round.votes.reload.count }
      end
    end

    context "with a ballot that carries no candidate key at all" do
      let(:ballots) { { "1" => { "for_lift" => "true" } } }

      it "stores no vote" do
        expect { save }.not_to change { round.votes.reload.count }
      end
    end

    context "with no ballots at all" do
      let(:ballots) { {} }

      it "changes nothing" do
        expect { save }.not_to change { round.votes.reload.count }
      end
    end
  end

  describe "a lift round" do
    let(:round) { create(:breakdown_vote_round, breakdown_phase: phase, kind: "lift", number: 1) }

    context "with both choices" do
      let(:ballots) { { "1" => { "for_lift" => "true" }, "2" => { "for_lift" => "false" } } }

      it "stores each choice" do
        save
        expect(round.votes.reload.map { |vote| [ vote.voter_seat, vote.for_lift ] }).to contain_exactly([ 1, true ], [ 2, false ])
      end

      it "leaves candidate_seat unset" do
        save
        expect(round.votes.reload.map(&:candidate_seat).uniq).to eq([ nil ])
      end
    end

    context "with a cleared choice" do
      let(:ballots) { { "1" => { "for_lift" => "" } } }

      before { create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 1, candidate_seat: nil, for_lift: true) }

      it "removes the vote" do
        expect { save }.to change { round.votes.reload.count }.by(-1)
      end
    end

    context "when the ballot carries a candidate seat instead of a lift choice" do
      let(:ballots) { { "1" => { "candidate_seat" => "4" } } }

      it "stores no vote" do
        expect { save }.not_to change { round.votes.reload.count }
      end
    end
  end
end
