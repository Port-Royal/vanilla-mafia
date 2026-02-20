require 'rails_helper'

RSpec.describe Rating, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:role).with_foreign_key(:role_code).with_primary_key(:code).optional }
  end

  describe 'validations' do
    subject { build(:rating) }

    it { is_expected.to validate_uniqueness_of(:player_id).scoped_to(:game_id) }
    it { is_expected.to validate_numericality_of(:plus).allow_nil }
    it { is_expected.to validate_numericality_of(:minus).allow_nil }
    it { is_expected.to validate_numericality_of(:best_move).allow_nil }
  end

  describe '#total' do
    context 'when plus and minus are present' do
      let(:rating) { build(:rating, plus: 3, minus: 1) }

      it 'returns plus minus minus' do
        expect(rating.total).to eq(2)
      end
    end

    context 'when plus is nil' do
      let(:rating) { build(:rating, plus: nil, minus: 2) }

      it 'treats nil plus as zero' do
        expect(rating.total).to eq(-2)
      end
    end

    context 'when minus is nil' do
      let(:rating) { build(:rating, plus: 5, minus: nil) }

      it 'treats nil minus as zero' do
        expect(rating.total).to eq(5)
      end
    end

    context 'when both are nil' do
      let(:rating) { build(:rating, plus: nil, minus: nil) }

      it 'returns zero' do
        expect(rating.total).to eq(0)
      end
    end

    context 'when extra_points is non-zero' do
      let(:rating) { build(:rating, plus: 3, minus: 1) }

      before { allow(rating).to receive(:extra_points).and_return(2) }

      it 'includes extra_points in the total' do
        expect(rating.total).to eq(4)
      end
    end
  end

  describe '#extra_points' do
    let(:rating) { build(:rating) }

    it 'returns zero' do
      expect(rating.extra_points).to eq(0)
    end
  end
end
