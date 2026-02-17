require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:ratings).dependent(:destroy) }
    it { is_expected.to have_many(:players).through(:ratings) }
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
    it 'returns games for the given season' do
      game_s1 = create(:game, season: 1)
      game_s2 = create(:game, season: 2)

      expect(described_class.for_season(1)).to include(game_s1)
      expect(described_class.for_season(1)).not_to include(game_s2)
    end
  end

  describe '.ordered' do
    it 'orders by played_on, series, game_number ascending' do
      third = create(:game, played_on: Date.new(2026, 1, 2), season: 1, series: 1, game_number: 1)
      first = create(:game, played_on: Date.new(2026, 1, 1), season: 1, series: 1, game_number: 2)
      second = create(:game, played_on: Date.new(2026, 1, 1), season: 1, series: 2, game_number: 1)

      expect(described_class.ordered).to eq([first, second, third])
    end
  end

  describe '#full_name' do
    it 'includes all parts when all fields are present' do
      game = build(:game, played_on: Date.new(2026, 1, 15), season: 1, series: 2, game_number: 3, name: "Финал")

      expect(game.full_name).to eq("2026-01-15 Сезон 1 Серия 2 Игра 3 Финал")
    end

    it 'omits played_on when nil' do
      game = build(:game, played_on: nil, season: 1, series: 2, game_number: 3, name: "Финал")

      expect(game.full_name).to eq("Сезон 1 Серия 2 Игра 3 Финал")
    end

    it 'omits name when nil' do
      game = build(:game, played_on: Date.new(2026, 1, 15), season: 1, series: 2, game_number: 3, name: nil)

      expect(game.full_name).to eq("2026-01-15 Сезон 1 Серия 2 Игра 3")
    end
  end

  describe '#in_season_name' do
    it 'returns series and game number' do
      game = build(:game, series: 3, game_number: 5)

      expect(game.in_season_name).to eq("Серия 3 Игра 5")
    end
  end
end
