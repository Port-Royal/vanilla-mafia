require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:competition) }
    it { is_expected.to have_many(:game_participations).dependent(:destroy) }
    it { is_expected.to have_many(:players).through(:game_participations) }
    it { is_expected.to have_many(:game_breakdowns).dependent(:nullify) }
  end

  describe 'validations' do
    subject { create(:game) }

    it { is_expected.to validate_presence_of(:game_number) }
    it { is_expected.to validate_numericality_of(:game_number).only_integer }
    it { is_expected.to validate_uniqueness_of(:game_number).scoped_to(:competition_id) }
    it { is_expected.to define_enum_for(:result).with_values(described_class::RESULTS).backed_by_column_of_type(:string) }
    it { is_expected.to validate_numericality_of(:table_number).only_integer.is_greater_than(0).allow_nil }

    it "allows nil table_number" do
      game = build(:game, table_number: nil)
      expect(game).to be_valid
    end

    it "accepts positive integer table_number" do
      game = build(:game, table_number: 3)
      expect(game).to be_valid
    end

    it "rejects zero table_number" do
      game = build(:game, table_number: 0)
      expect(game).not_to be_valid
      expect(game.errors[:table_number]).to be_present
    end

    it "rejects negative table_number" do
      game = build(:game, table_number: -1)
      expect(game).not_to be_valid
      expect(game.errors[:table_number]).to be_present
    end

    it { is_expected.to validate_numericality_of(:games_total).only_integer.is_greater_than(0).allow_nil }

    context "with games_total" do
      subject(:game) { build(:game, game_number: 3, games_total: games_total) }

      context "when games_total is blank" do
        let(:games_total) { nil }

        it { is_expected.to be_valid }
      end

      context "when games_total equals game_number" do
        let(:games_total) { 3 }

        it { is_expected.to be_valid }
      end

      context "when games_total is greater than game_number" do
        let(:games_total) { 8 }

        it { is_expected.to be_valid }
      end

      context "when games_total is less than game_number" do
        let(:games_total) { 2 }

        it "is invalid with an error on games_total" do
          game.validate
          expect(game.errors.added?(:games_total, :greater_than_or_equal_to, count: 3)).to be(true)
        end
      end
    end

    context "when game_number is blank and games_total is set" do
      subject(:game) { build(:game, game_number: nil, games_total: 8) }

      it "reports only the missing game_number" do
        game.validate
        expect(game.errors.attribute_names).to eq([ :game_number ])
      end
    end

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

  describe 'draw result' do
    let(:game) { build(:game, result: "draw") }

    it 'is valid' do
      expect(game).to be_valid
    end

    it 'exposes the draw value' do
      expect(described_class::RESULTS[:draw]).to eq("draw")
    end
  end

  describe '#roles_public?' do
    {
      [ "in_progress", true ] => false,
      [ "in_progress", false ] => true,
      [ "draw", true ] => true,
      [ "peace_victory", false ] => true
    }.each do |(result, hide_roles), expected|
      context "when result is #{result} and hide_roles is #{hide_roles}" do
        let(:game) { build(:game, result:, hide_roles:) }

        it "returns #{expected}" do
          expect(game.roles_public?).to be(expected)
        end
      end
    end
  end

  describe '#current_nominees' do
    let_it_be(:nominated_game) { create(:game) }

    before do
      create(:game_protocol_event, game: nominated_game, position: 2, kind: "nominate", actor_seat: 2, target_seats: [ 3 ])
      create(:game_protocol_event, game: nominated_game, position: 1, kind: "nominate", actor_seat: 1, target_seats: [ 5 ])
      create(:game_protocol_event, position: 1, kind: "nominate", actor_seat: 1, target_seats: [ 8 ])
    end

    it "replays this game's journal in position order" do
      expect(nominated_game.current_nominees).to eq([ 5, 3 ])
    end
  end

  describe '#public_fouls' do
    let(:fouled_game) { create(:game, hide_roles: true) }
    let(:sanction) { ->(position, kind, seat, metadata = {}) { create(:game_protocol_event, game: fouled_game, position:, kind:, target_seats: [ seat ], metadata:) } }

    before do
      sanction.call(1, "foul", 3)
      sanction.call(2, "foul", 3)
      sanction.call(3, "tech", 3)
      sanction.call(4, "foul", 7)
      sanction.call(5, "sanction_cancelled", 7, { "sanction" => "foul" })
      sanction.call(6, "tech", 5)
      sanction.call(7, "tech", 5)
      sanction.call(8, "sanction_cancelled", 5, { "sanction" => "tech" })
      create(:game_protocol_event, position: 1, kind: "foul", target_seats: [ 9 ])
    end

    it "never counts below zero for a cancellation with nothing to cancel" do
      sanction.call(9, "sanction_cancelled", 8, { "sanction" => "foul" })

      expect(fouled_game.public_fouls).not_to have_key(8)
    end

    it "counts each seat's fouls and technical fouls, cancellations included, even with roles hidden" do
      expect(fouled_game.public_fouls).to eq(3 => { fouls: 2, tech: 1 }, 5 => { fouls: 0, tech: 1 })
    end
  end

  describe '#public_shots' do
    let(:shot_game) { create(:game, hide_roles:) }
    let(:hide_roles) { false }
    let(:night_event) { ->(position, kind, day, targets, metadata = {}) { create(:game_protocol_event, game: shot_game, position:, kind:, phase: "night", day_number: day, target_seats: targets, metadata:) } }

    before do
      create(:role, code: "mafia") unless Role.exists?(code: "mafia")
      create(:game_participation, game: shot_game, seat: 5, role_code: "mafia")
      night_event.call(3, "shot", 1, [ 5 ])
      night_event.call(1, "miss_shot", 0, [ 7 ], { "miss" => nil })
      night_event.call(2, "miss_shot", 0, [], { "miss" => "no_shot" })
      create(:game_protocol_event, kind: "shot", phase: "night", day_number: 0, target_seats: [ 9 ])
    end

    it "gives one entry per night of this game, a miss with no seat, the target's team" do
      expect(shot_game.public_shots).to eq([ { night: 1, target_seat: nil, team: nil }, { night: 2, target_seat: 5, team: "black" } ])
    end

    it "gives a target with a role outside the game's four no team" do
      create(:role, code: "maf") unless Role.exists?(code: "maf")
      create(:game_participation, game: shot_game, seat: 6, role_code: "maf")
      night_event.call(4, "shot", 2, [ 6 ])

      expect(shot_game.public_shots.last).to eq(night: 3, target_seat: 6, team: nil)
    end

    it "gives a civilian target the red team" do
      create(:role, code: "peace") unless Role.exists?(code: "peace")
      create(:game_participation, game: shot_game, seat: 6, role_code: "peace")
      night_event.call(4, "shot", 2, [ 6 ])

      expect(shot_game.public_shots.last).to eq(night: 3, target_seat: 6, team: "red")
    end

    context "when roles are hidden" do
      let(:hide_roles) { true }

      it "still gives the shots, since a kill is public, without the team" do
        expect(shot_game.public_shots).to eq([ { night: 1, target_seat: nil, team: nil }, { night: 2, target_seat: 5, team: nil } ])
      end
    end
  end

  describe '#public_checks' do
    let(:checked_game) { create(:game, hide_roles:, result:) }
    let(:hide_roles) { false }
    let(:result) { "in_progress" }

    before do
      create(:game_protocol_event, game: checked_game, position: 3, kind: "sheriff_check", phase: "night", day_number: 1, actor_seat: 2, target_seats: [ 4 ], metadata: { "result" => "black" })
      create(:game_protocol_event, game: checked_game, position: 1, kind: "don_check", phase: "night", day_number: 0, actor_seat: 1, target_seats: [ 2 ], metadata: { "result" => "sheriff" })
      create(:game_protocol_event, game: checked_game, position: 2, kind: "don_check", phase: "night", day_number: 1, actor_seat: 1, target_seats: [], metadata: { "result" => nil })
      create(:game_protocol_event, position: 1, kind: "don_check", phase: "night", day_number: 0, target_seats: [ 5 ], metadata: { "result" => "not_sheriff" })
    end

    before do
      create(:role, code: "mafia") unless Role.exists?(code: "mafia")
      create(:game_participation, game: checked_game, seat: 4, role_code: "mafia")
    end

    it "lists the checks of this game in order, a skipped check with no seat, with the target's team" do
      expect(checked_game.public_checks).to eq([
        { night: 1, kind: "don", target_seat: 2, result: "sheriff", team: nil },
        { night: 2, kind: "don", target_seat: nil, result: nil, team: nil },
        { night: 2, kind: "sheriff", target_seat: 4, result: "black", team: "black" }
      ])
    end

    context "when roles are hidden in a running game" do
      let(:hide_roles) { true }

      it "gives nothing" do
        expect(checked_game.public_checks).to eq([])
      end
    end

    context "when roles are hidden in a finished game" do
      let(:hide_roles) { true }
      let(:result) { "draw" }

      it "gives the checks" do
        expect(checked_game.public_checks.size).to eq(3)
      end
    end
  end

  describe '.finished' do
    let_it_be(:competition) { create(:competition, :series) }
    let_it_be(:draw_game) { create(:game, competition:, game_number: 1, result: "draw") }
    let_it_be(:running_game) { create(:game, competition:, game_number: 2, result: "in_progress") }

    it 'includes a draw' do
      expect(described_class.finished).to include(draw_game)
    end

    it 'excludes a game in progress' do
      expect(described_class.finished).not_to include(running_game)
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

  describe "slug" do
    describe "generation" do
      let_it_be(:season) { create(:competition, :season, slug: "season-3") }
      let_it_be(:series) { create(:competition, :series, slug: "season-3-series-1", parent: season) }

      it "generates slug from competition slug and game number" do
        game = create(:game, competition: series, game_number: 7)
        expect(game.slug).to eq("season-3-series-1-game-7")
      end

      it "appends hex tail on collision" do
        create(:game, competition: series, game_number: 10, slug: "season-3-series-1-game-11")
        game = build(:game, competition: series, game_number: 11)
        game.valid?
        expect(game.slug).to start_with("season-3-series-1-game-11-")
        expect(game.slug.length).to eq("season-3-series-1-game-11-".length + 4)
      end

      it "does not change slug when game_number is updated" do
        game = create(:game, competition: series, game_number: 8)
        original_slug = game.slug
        game.update!(game_number: 99)
        expect(game.slug).to eq(original_slug)
      end
    end

    describe "#to_param" do
      let_it_be(:season) { create(:competition, :season, slug: "season-4") }
      let_it_be(:series) { create(:competition, :series, slug: "season-4-series-2", parent: season) }

      it "returns the slug" do
        game = create(:game, competition: series, game_number: 5)
        expect(game.to_param).to eq("season-4-series-2-game-5")
      end
    end
  end
end
