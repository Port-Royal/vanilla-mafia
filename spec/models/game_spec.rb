require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:competition) }
    it { is_expected.to have_many(:game_participations).dependent(:destroy) }
    it { is_expected.to have_many(:players).through(:game_participations) }
  end

  describe 'callbacks' do
    context 'when competition has legacy_season and legacy_series' do
      let_it_be(:parent) { create(:competition, :season, legacy_season: 7) }
      let_it_be(:series_comp) { create(:competition, :series, legacy_season: 7, legacy_series: 3, parent: parent) }
      let(:game) { build(:game, competition: series_comp, season: nil, series: nil) }

      it 'derives season from competition' do
        game.valid?
        expect(game.season).to eq(7)
      end

      it 'derives series from competition' do
        game.valid?
        expect(game.series).to eq(3)
      end
    end

    context 'when competition has only legacy_season' do
      let_it_be(:season_comp) { create(:competition, :season, legacy_season: 4) }
      let(:game) { build(:game, competition: season_comp, season: nil, series: nil) }

      it 'derives season from competition' do
        game.valid?
        expect(game.season).to eq(4)
      end

      it 'leaves series as nil' do
        game.valid?
        expect(game.series).to be_nil
      end
    end

    context 'when competition_id changes on a persisted game' do
      let_it_be(:old_comp) { create(:competition, :series, legacy_season: 1, legacy_series: 1) }
      let_it_be(:new_comp) { create(:competition, :series, legacy_season: 2, legacy_series: 5) }
      let!(:game) { create(:game, competition: old_comp) }

      it 're-derives season from the new competition' do
        game.competition = new_comp
        game.valid?
        expect(game.season).to eq(2)
      end

      it 're-derives series from the new competition' do
        game.competition = new_comp
        game.valid?
        expect(game.series).to eq(5)
      end
    end
  end

  describe 'validations' do
    subject { create(:game) }

    it { is_expected.to validate_presence_of(:game_number) }
    it { is_expected.to validate_numericality_of(:game_number).only_integer }
    it { is_expected.to validate_uniqueness_of(:game_number).scoped_to(:competition_id) }

    context 'when competition lacks legacy_season' do
      let(:comp) { create(:competition, :series, legacy_season: nil) }
      let(:game) { build(:game, competition: comp) }

      it 'is invalid' do
        expect(game).not_to be_valid
        expect(game.errors[:season]).to be_present
      end
    end
    it { is_expected.to define_enum_for(:result).with_values(described_class::RESULTS).backed_by_column_of_type(:string) }

    it 'rejects invalid result values' do
      game = build(:game)
      game.result = "invalid"
      expect(game).not_to be_valid
      expect(game.errors[:result]).to be_present
    end

    it 'allows same game_number across different competitions' do
      comp_a = create(:competition, :series)
      comp_b = create(:competition, :series)
      create(:game, game_number: 1, competition: comp_a)
      game = build(:game, game_number: 1, competition: comp_b)
      expect(game).to be_valid
    end

    it 'rejects duplicate game_number within same competition' do
      comp = create(:competition, :series)
      create(:game, game_number: 1, competition: comp)
      game = build(:game, game_number: 1, competition: comp)
      expect(game).not_to be_valid
      expect(game.errors[:game_number]).to be_present
    end
  end

  describe '.for_competition' do
    let_it_be(:competition) { create(:competition, :series) }
    let_it_be(:other_competition) { create(:competition, :series) }
    let_it_be(:game_in_comp) { create(:game, competition: competition) }
    let_it_be(:game_in_other) { create(:game, competition: other_competition) }

    it 'returns games for the given competition' do
      expect(described_class.for_competition(competition)).to include(game_in_comp)
      expect(described_class.for_competition(competition)).not_to include(game_in_other)
    end
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
    let_it_be(:competition) { create(:competition, :series) }
    let_it_be(:third) { create(:game, competition: competition, played_on: Date.new(2026, 1, 2), season: 1, series: 1, game_number: 1) }
    let_it_be(:first) { create(:game, competition: competition, played_on: Date.new(2026, 1, 1), season: 1, series: 1, game_number: 2) }
    let_it_be(:second) { create(:game, competition: competition, played_on: Date.new(2026, 1, 1), season: 1, series: 2, game_number: 3) }

    it 'orders by played_on, series, game_number ascending' do
      expect(described_class.ordered).to eq([ first, second, third ])
    end
  end

  describe '.available_seasons' do
    context 'when games exist in multiple seasons' do
      let_it_be(:game_s3) { create(:game, season: 30, series: 90) }
      let_it_be(:game_s1) { create(:game, season: 10, series: 91) }
      let_it_be(:game_s5) { create(:game, season: 50, series: 92) }
      let_it_be(:game_s1_dup) { create(:game, season: 10, series: 93) }

      it 'returns distinct seasons including created ones' do
        result = described_class.available_seasons
        expect(result).to include(10, 30, 50)
        expect(result.count(10)).to eq(1)
      end

      it 'returns seasons in ascending order' do
        result = described_class.available_seasons
        idx_10 = result.index(10)
        idx_30 = result.index(30)
        idx_50 = result.index(50)
        expect(idx_10).to be < idx_30
        expect(idx_30).to be < idx_50
      end
    end

    context 'when no games exist' do
      it 'returns an empty array' do
        expect(described_class.available_seasons).to eq([])
      end
    end
  end

  describe '#full_name' do
    let_it_be(:parent) { create(:competition, :season, name: "Сезон 1") }
    let_it_be(:child) { create(:competition, :series, name: "Серия 2", parent: parent) }

    context 'when all fields are present' do
      let(:game) { build(:game, competition: child, played_on: Date.new(2026, 1, 15), game_number: 3, name: "Финал") }

      it 'includes all parts from competition hierarchy' do
        expect(game.full_name).to eq("2026-01-15 Сезон 1 Серия 2 Игра 3 Финал")
      end
    end

    context 'when played_on is nil' do
      let(:game) { build(:game, competition: child, played_on: nil, game_number: 3, name: "Финал") }

      it 'omits played_on' do
        expect(game.full_name).to eq("Сезон 1 Серия 2 Игра 3 Финал")
      end
    end

    context 'when name is nil' do
      let(:game) { build(:game, competition: child, played_on: Date.new(2026, 1, 15), game_number: 3, name: nil) }

      it 'omits name' do
        expect(game.full_name).to eq("2026-01-15 Сезон 1 Серия 2 Игра 3")
      end
    end

    context 'when competition has no parent' do
      let_it_be(:root) { create(:competition, :season, name: "Турнир") }
      let(:game) { build(:game, competition: root, played_on: nil, game_number: 1, name: nil) }

      it 'shows only competition name and game number' do
        expect(game.full_name).to eq("Турнир Игра 1")
      end
    end
  end

  describe '#in_season_name' do
    let_it_be(:parent) { create(:competition, :season, name: "Сезон 3") }
    let_it_be(:child) { create(:competition, :series, name: "Серия 5", parent: parent) }
    let(:game) { build(:game, competition: child, game_number: 5) }

    it 'returns competition name and game number' do
      expect(game.in_season_name).to eq("Серия 5 Игра 5")
    end

    context 'when competition has no parent' do
      let_it_be(:root) { create(:competition, :season, name: "Кубок") }
      let(:game) { build(:game, competition: root, game_number: 2) }

      it 'returns competition name and game number' do
        expect(game.in_season_name).to eq("Кубок Игра 2")
      end
    end
  end
end
