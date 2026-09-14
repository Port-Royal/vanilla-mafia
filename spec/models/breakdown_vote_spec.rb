require "rails_helper"

RSpec.describe BreakdownVote, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:breakdown_vote_round) }
  end

  describe "validations" do
    subject { build(:breakdown_vote) }

    it { is_expected.to validate_uniqueness_of(:voter_seat).scoped_to(:breakdown_vote_round_id) }
    it { is_expected.to validate_numericality_of(:voter_seat).only_integer.is_in(1..10) }
    it { is_expected.to validate_numericality_of(:candidate_seat).only_integer.is_in(1..10) }
  end

  describe "missing round" do
    subject(:vote) { build(:breakdown_vote, breakdown_vote_round: nil, candidate_seat: nil, for_lift: true) }

    before { vote.validate }

    it "only reports the missing round" do
      expect(vote.errors.attribute_names).to eq([ :breakdown_vote_round ])
    end
  end

  describe "round kind constraints" do
    let_it_be(:main_round) { create(:breakdown_vote_round, kind: "main") }
    let_it_be(:revote_round) { create(:breakdown_vote_round, kind: "revote") }
    let_it_be(:lift_round) { create(:breakdown_vote_round, kind: "lift") }

    context "when a main vote has a candidate" do
      subject { build(:breakdown_vote, breakdown_vote_round: main_round, candidate_seat: 5) }

      it { is_expected.to be_valid }
    end

    context "when a revote has no candidate" do
      subject(:vote) { build(:breakdown_vote, breakdown_vote_round: revote_round, candidate_seat: nil) }

      before { vote.validate }

      it "adds a not_a_number error" do
        expect(vote.errors).to be_of_kind(:candidate_seat, :not_a_number)
      end
    end

    context "when a main vote has for_lift set to false" do
      subject(:vote) { build(:breakdown_vote, breakdown_vote_round: main_round, for_lift: false) }

      before { vote.validate }

      it "adds a present error" do
        expect(vote.errors).to be_of_kind(:for_lift, :present)
      end
    end

    context "when a lift vote is for lifting" do
      subject { build(:breakdown_vote, :lift, breakdown_vote_round: lift_round, for_lift: true) }

      it { is_expected.to be_valid }
    end

    context "when a lift vote is against lifting" do
      subject { build(:breakdown_vote, :lift, breakdown_vote_round: lift_round, for_lift: false) }

      it { is_expected.to be_valid }
    end

    context "when a lift vote has no decision" do
      subject(:vote) { build(:breakdown_vote, :lift, breakdown_vote_round: lift_round, for_lift: nil) }

      before { vote.validate }

      it "adds an inclusion error" do
        expect(vote.errors).to be_of_kind(:for_lift, :inclusion)
      end
    end

    context "when a lift vote has a candidate" do
      subject(:vote) { build(:breakdown_vote, :lift, breakdown_vote_round: lift_round, candidate_seat: 5) }

      before { vote.validate }

      it "adds a present error" do
        expect(vote.errors).to be_of_kind(:candidate_seat, :present)
      end
    end
  end
end
