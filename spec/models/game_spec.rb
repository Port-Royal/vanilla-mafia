require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:competition) }
    it { is_expected.to have_many(:game_participations).dependent(:destroy) }
    it { is_expected.to have_many(:players).through(:game_participations) }
  end

  describe 'validations' do
    subject { create(:game) }

    it { is_expected.to validate_presence_of(:game_number) }
    it { is_expected.to validate_numericality_of(:game_number).only_integer }
    it { is_expected.to validate_uniqueness_of(:game_number).scoped_to(:competition_id) }
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

  describe '.ordered' do
    let_it_be(:competition) { create(:competition, :series) }
    let_it_be(:second) { create(:game, competition: competition, played_on: Date.new(2026, 1, 1), game_number: 2) }
    let_it_be(:first) { create(:game, competition: competition, played_on: Date.new(2026, 1, 1), game_number: 1) }
    let_it_be(:third) { create(:game, competition: competition, played_on: Date.new(2026, 1, 2), game_number: 3) }

    it 'orders by played_on, game_number ascending' do
      expect(described_class.ordered).to eq([ first, second, third ])
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
