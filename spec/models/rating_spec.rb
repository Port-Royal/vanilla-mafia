require 'rails_helper'

RSpec.describe Rating, type: :model do
  describe '#total' do
    it 'returns plus minus minus' do
      rating = build(:rating, plus: 3, minus: 1)

      expect(rating.total).to eq(2)
    end

    it 'treats nil plus as zero' do
      rating = build(:rating, plus: nil, minus: 2)

      expect(rating.total).to eq(-2)
    end

    it 'treats nil minus as zero' do
      rating = build(:rating, plus: 5, minus: nil)

      expect(rating.total).to eq(5)
    end

    it 'returns zero when both are nil' do
      rating = build(:rating, plus: nil, minus: nil)

      expect(rating.total).to eq(0)
    end

    it 'includes extra_points in the total' do
      rating = build(:rating, plus: 3, minus: 1)
      allow(rating).to receive(:extra_points).and_return(2)

      expect(rating.total).to eq(4)
    end
  end

  describe '#extra_points' do
    it 'returns zero' do
      rating = build(:rating)

      expect(rating.extra_points).to eq(0)
    end
  end
end
