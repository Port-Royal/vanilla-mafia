require "rails_helper"

RSpec.describe GameBreakdown, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:author).class_name("User") }
    it { is_expected.to belong_to(:game).optional }
    it { is_expected.to have_many(:seats).class_name("BreakdownSeat").order(:number).dependent(:destroy) }
    it { is_expected.to have_many(:phases).class_name("BreakdownPhase").order(:position).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:game_breakdown) }

    it { is_expected.to validate_presence_of(:title) }
  end

  describe "roles_mode enum" do
    it "defines the expected mapping" do
      expect(described_class.roles_modes).to eq("open" => "open", "closed" => "closed")
    end

    it "defaults new records to open" do
      expect(described_class.new).to be_open
    end

    context "when roles_mode is unknown" do
      subject { build(:game_breakdown, roles_mode: "secret") }

      it { is_expected.to be_invalid }
    end
  end

  describe "manual_result enum" do
    it "defines the expected mapping" do
      expect(described_class.manual_results).to eq("city" => "city", "mafia" => "mafia", "draw" => "draw")
    end

    it "exposes prefixed predicate methods" do
      expect(described_class.new(manual_result: "draw")).to be_manual_result_draw
    end

    context "when manual_result is nil" do
      subject { build(:game_breakdown, manual_result: nil) }

      it { is_expected.to be_valid }
    end

    context "when manual_result is unknown" do
      subject { build(:game_breakdown, manual_result: "nobody") }

      it { is_expected.to be_invalid }
    end
  end

  describe "creation" do
    context "without a linked game" do
      let_it_be(:breakdown) { create(:game_breakdown) }

      it "creates 10 seats numbered 1..10" do
        expect(breakdown.seats.pluck(:number)).to eq((1..10).to_a)
      end

      it "leaves seats empty" do
        expect(breakdown.seats.pluck(:name, :player_id, :role_code).uniq).to eq([ [ nil, nil, nil ] ])
      end

      it "creates the zero round phase" do
        expect(breakdown.phases.pluck(:position)).to eq([ 0 ])
      end
    end

    context "with a linked game" do
      let_it_be(:game) { create(:game) }
      let_it_be(:role) { create(:role, code: "sheriff") }
      let_it_be(:player) { create(:player, name: "Кот") }
      let_it_be(:participation) { create(:game_participation, game: game, player: player, role: role, seat: 1) }
      let_it_be(:unseated) { create(:game_participation, game: game, role: role, seat: nil) }
      let_it_be(:breakdown) { create(:game_breakdown, game: game) }

      let(:seat) { breakdown.seats.find_by(number: 1) }

      it "copies the player name into the matching seat" do
        expect(seat.name).to eq("Кот")
      end

      it "links the player to the matching seat" do
        expect(seat.player).to eq(player)
      end

      it "copies the role into the matching seat" do
        expect(seat.role_code).to eq("sheriff")
      end

      it "leaves other seats empty" do
        expect(breakdown.seats.where.not(number: 1).pluck(:name, :player_id, :role_code).uniq).to eq([ [ nil, nil, nil ] ])
      end

      it "still creates exactly 10 seats" do
        expect(breakdown.seats.count).to eq(10)
      end
    end
  end

  describe "destruction" do
    let!(:breakdown) { create(:game_breakdown) }
    let!(:night) { create(:breakdown_phase, :night, game_breakdown: breakdown, position: 1) }
    let!(:day) { create(:breakdown_phase, game_breakdown: breakdown, position: 2) }
    let!(:round) { create(:breakdown_vote_round, breakdown_phase: day, kind: "revote") }
    let!(:justification) { create(:breakdown_speech, :justification, breakdown_phase: day, breakdown_vote_round: round) }

    before do
      create(:breakdown_night_action, breakdown_phase: night)
      create(:breakdown_move, breakdown_speech: justification)
      create(:breakdown_move, :in_vote_round, breakdown_vote_round: round)
      create(:breakdown_vote, breakdown_vote_round: round)
    end

    it "removes all nested records" do
      expect { breakdown.destroy! }
        .to change(BreakdownSeat, :count).by(-10)
        .and change(BreakdownPhase, :count).by(-3)
        .and change(BreakdownNightAction, :count).by(-1)
        .and change(BreakdownSpeech, :count).by(-1)
        .and change(BreakdownVoteRound, :count).by(-1)
        .and change(BreakdownVote, :count).by(-1)
        .and change(BreakdownMove, :count).by(-2)
    end
  end
end
