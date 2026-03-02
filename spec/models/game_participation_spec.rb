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
end
