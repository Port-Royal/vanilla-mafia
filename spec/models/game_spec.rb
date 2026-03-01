require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:game_participations).dependent(:destroy) }
    it { is_expected.to have_many(:players).through(:game_participations) }
  end

  describe 'validations' do
    subject { build(:game) }

    it { is_expected.to validate_presence_of(:season) }
    it { is_expected.to validate_numericality_of(:season).only_integer }
    it { is_expected.to validate_presence_of(:series) }
    it { is_expected.to validate_numericality_of(:series).only_integer }
    it { is_expected.to validate_presence_of(:game_number) }
    it { is_expected.to validate_numericality_of(:game_number).only_integer }
    it { is_expected.to validate_uniqueness_of(:game_number).scoped_to(:season, :series) }
  end

  describe '.for_season' do
    let_it_be(:game_s1) { create(:game, season: 1) }
    let_it_be(:game_s2) { create(:game, season: 2) }

    it 'returns games for the given season' do
      expect(described_class.for_season(1)).to include(game_s1)
      expect(described_class.for_season(1)).not_to include(game_s2)
    end
  end

  describe '.ordered' do
    let_it_be(:third) { create(:game, played_on: Date.new(2026, 1, 2), season: 1, series: 1, game_number: 1) }
    let_it_be(:first) { create(:game, played_on: Date.new(2026, 1, 1), season: 1, series: 1, game_number: 2) }
    let_it_be(:second) { create(:game, played_on: Date.new(2026, 1, 1), season: 1, series: 2, game_number: 1) }

    it 'orders by played_on, series, game_number ascending' do
      expect(described_class.ordered).to eq([ first, second, third ])
    end
  end

  describe '.available_seasons' do
    context 'when games exist in multiple seasons' do
      let_it_be(:game_s3) { create(:game, season: 3) }
      let_it_be(:game_s1) { create(:game, season: 1) }
      let_it_be(:game_s5) { create(:game, season: 5) }
      let_it_be(:game_s1_dup) { create(:game, season: 1, series: 2) }

      it 'returns distinct seasons sorted ascending' do
        expect(described_class.available_seasons).to eq([ 1, 3, 5 ])
      end
    end

    context 'when no games exist' do
      it 'returns an empty array' do
        expect(described_class.available_seasons).to eq([])
      end
    end
  end

  describe '#full_name' do
    context 'when all fields are present' do
      let(:game) { build(:game, played_on: Date.new(2026, 1, 15), season: 1, series: 2, game_number: 3, name: "Финал") }

      it 'includes all parts' do
        expect(game.full_name).to eq("2026-01-15 Сезон 1 Серия 2 Игра 3 Финал")
      end
    end

    context 'when played_on is nil' do
      let(:game) { build(:game, played_on: nil, season: 1, series: 2, game_number: 3, name: "Финал") }

      it 'omits played_on' do
        expect(game.full_name).to eq("Сезон 1 Серия 2 Игра 3 Финал")
      end
    end

    context 'when name is nil' do
      let(:game) { build(:game, played_on: Date.new(2026, 1, 15), season: 1, series: 2, game_number: 3, name: nil) }

      it 'omits name' do
        expect(game.full_name).to eq("2026-01-15 Сезон 1 Серия 2 Игра 3")
      end
    end
  end

  describe '#in_season_name' do
    let(:game) { build(:game, series: 3, game_number: 5) }

    it 'returns series and game number' do
      expect(game.in_season_name).to eq("Серия 3 Игра 5")
    end
  end
end
