require 'rails_helper'

RSpec.describe GameParticipation, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:role).with_foreign_key(:role_code).with_primary_key(:code).optional }
  end

  describe 'validations' do
    subject { build(:game_participation) }

    it { is_expected.to validate_uniqueness_of(:player_id).scoped_to(:game_id) }
    it { is_expected.to validate_numericality_of(:plus).allow_nil }
    it { is_expected.to validate_numericality_of(:minus).allow_nil }
    it { is_expected.to validate_numericality_of(:best_move).allow_nil }
    it { is_expected.to validate_numericality_of(:seat).only_integer.allow_nil }
    it { is_expected.to validate_uniqueness_of(:seat).scoped_to(:game_id).allow_nil }

    context "when seat is within valid range" do
      it "is valid with seat 1" do
        subject.seat = 1
        subject.validate
        expect(subject.errors[:seat]).to be_empty
      end

      it "is valid with seat 10" do
        subject.seat = 10
        subject.validate
        expect(subject.errors[:seat]).to be_empty
      end
    end

    context "when seat is out of range" do
      it "is invalid with seat 0" do
        subject.seat = 0
        subject.validate
        expect(subject.errors[:seat]).to be_present
      end

      it "is invalid with seat 11" do
        subject.seat = 11
        subject.validate
        expect(subject.errors[:seat]).to be_present
      end
    end
  end

  describe "status enum" do
    it "defines the expected mapping" do
      expect(described_class.statuses).to eq(
        "alive" => 0,
        "killed_by_mafia" => 1,
        "voted_out" => 2,
        "banned" => 3
      )
    end

    it "defaults new records to alive" do
      expect(described_class.new.status).to eq("alive")
    end

    it "exposes predicate methods" do
      participation = described_class.new(status: :killed_by_mafia)
      expect(participation).to be_killed_by_mafia
      expect(participation).not_to be_alive
    end

    it "raises on unknown statuses" do
      expect { described_class.new(status: :vaporized) }.to raise_error(ArgumentError)
    end
  end

  describe '#total' do
    context 'when plus and minus are present' do
      let(:participation) { build(:game_participation, plus: 3, minus: 1) }

      it 'returns plus minus minus' do
        expect(participation.total).to eq(2)
      end
    end

    context 'when plus is nil' do
      let(:participation) { build(:game_participation, plus: nil, minus: 2) }

      it 'treats nil plus as zero' do
        expect(participation.total).to eq(-2)
      end
    end

    context 'when minus is nil' do
      let(:participation) { build(:game_participation, plus: 5, minus: nil) }

      it 'treats nil minus as zero' do
        expect(participation.total).to eq(5)
      end
    end

    context 'when both are nil' do
      let(:participation) { build(:game_participation, plus: nil, minus: nil) }

      it 'returns zero' do
        expect(participation.total).to eq(0)
      end
    end

    context 'when best_move is present' do
      let(:participation) { build(:game_participation, plus: 3, minus: 1, best_move: 0.5) }

      it 'includes best_move in the total' do
        expect(participation.total).to eq(2.5)
      end
    end

    context 'when best_move is nil' do
      let(:participation) { build(:game_participation, plus: 3, minus: 1, best_move: nil) }

      it 'treats nil best_move as zero' do
        expect(participation.total).to eq(2)
      end
    end
  end

  describe '#result' do
    let(:game) { build(:game, result: game_result) }
    let(:participation) { build(:game_participation, game:, role_code: role_code) }

    context 'when game is in progress' do
      let(:game_result) { "in_progress" }
      let(:role_code) { "peace" }

      it 'returns nil' do
        expect(participation.result).to be_nil
      end
    end

    context 'when role_code is blank' do
      let(:game_result) { "peace_victory" }
      let(:role_code) { nil }

      it 'returns nil' do
        expect(participation.result).to be_nil
      end
    end

    context 'when peaceful team wins' do
      let(:game_result) { "peace_victory" }

      context 'when player is peace' do
        let(:role_code) { "peace" }

        it 'returns win' do
          expect(participation.result).to eq("win")
        end
      end

      context 'when player is sheriff' do
        let(:role_code) { "sheriff" }

        it 'returns win' do
          expect(participation.result).to eq("win")
        end
      end

      context 'when player is mafia' do
        let(:role_code) { "mafia" }

        it 'returns lose' do
          expect(participation.result).to eq("lose")
        end
      end

      context 'when player is don' do
        let(:role_code) { "don" }

        it 'returns lose' do
          expect(participation.result).to eq("lose")
        end
      end
    end

    context 'when mafia wins' do
      let(:game_result) { "mafia_victory" }

      context 'when player is mafia' do
        let(:role_code) { "mafia" }

        it 'returns win' do
          expect(participation.result).to eq("win")
        end
      end

      context 'when player is don' do
        let(:role_code) { "don" }

        it 'returns win' do
          expect(participation.result).to eq("win")
        end
      end

      context 'when player is peace' do
        let(:role_code) { "peace" }

        it 'returns lose' do
          expect(participation.result).to eq("lose")
        end
      end

      context 'when player is sheriff' do
        let(:role_code) { "sheriff" }

        it 'returns lose' do
          expect(participation.result).to eq("lose")
        end
      end
    end
  end
end
