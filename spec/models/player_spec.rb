require 'rails_helper'

RSpec.describe Player, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:ratings).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:games).through(:ratings) }
    it { is_expected.to have_many(:player_awards).dependent(:destroy) }
    it { is_expected.to have_many(:awards).through(:player_awards) }
    it { is_expected.to have_many(:player_claims).dependent(:destroy) }
    it { is_expected.to have_one(:user) }
  end

  describe 'validations' do
    subject { build(:player) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe '#claimed?' do
    context 'when player has a user' do
      let(:player) { create(:player) }

      before { create(:user, player: player) }

      it 'returns true' do
        expect(player.claimed?).to be true
      end
    end

    context 'when player has no user' do
      let(:player) { build(:player) }

      it 'returns false' do
        expect(player.claimed?).to be false
      end
    end
  end

  describe '#claimed_by?' do
    let(:player) { create(:player) }
    let(:user) { create(:user, player: player) }

    context 'when the given user is the claiming user' do
      it 'returns true' do
        expect(player.claimed_by?(user)).to be true
      end
    end

    context 'when the given user is a different user' do
      let(:other_user) { create(:user) }

      it 'returns false' do
        expect(player.claimed_by?(other_user)).to be false
      end
    end
  end

  describe '#claimed?' do
    context 'when player has a user' do
      let(:player) { create(:player) }

      before { create(:user, player: player) }

      it 'returns true' do
        expect(player.claimed?).to be true
      end
    end

    context 'when player has no user' do
      let(:player) { build(:player) }

      it 'returns false' do
        expect(player.claimed?).to be false
      end
    end
  end

  describe '#claimed_by?' do
    let(:player) { create(:player) }
    let(:user) { create(:user, player: player) }

    context 'when the given user is the claiming user' do
      it 'returns true' do
        expect(player.claimed_by?(user)).to be true
      end
    end

    context 'when the given user is a different user' do
      let(:other_user) { create(:user) }

      it 'returns false' do
        expect(player.claimed_by?(other_user)).to be false
      end
    end
  end

  describe '.ordered' do
    let_it_be(:charlie) { create(:player, name: 'Charlie', position: 2) }
    let_it_be(:alice) { create(:player, name: 'Alice', position: 1) }
    let_it_be(:bob) { create(:player, name: 'Bob', position: 1) }

    it 'orders by position ascending then name ascending' do
      expect(described_class.ordered).to eq([ alice, bob, charlie ])
    end
  end

  describe '.ranked' do
    context 'when players have different stats' do
      let_it_be(:alice) { create(:player, name: 'Alice') }
      let_it_be(:bob) { create(:player, name: 'Bob') }
      let_it_be(:charlie) { create(:player, name: 'Charlie') }
      let_it_be(:game1) { create(:game, season: 1, series: 1, game_number: 1) }
      let_it_be(:game2) { create(:game, season: 1, series: 1, game_number: 2) }

      before do
        # Alice: total_rating=2, wins=1, games=1
        create(:rating, player: alice, game: game1, plus: 3, minus: 1, win: true)
        # Bob: total_rating=2, wins=1, games=2
        create(:rating, player: bob, game: game1, plus: 1, minus: 0, win: true)
        create(:rating, player: bob, game: game2, plus: 1, minus: 0, win: false)
        # Charlie: total_rating=5, wins=1, games=1
        create(:rating, player: charlie, game: game2, plus: 5, minus: 0, win: true)
      end

      it 'orders by total_rating DESC, wins_count DESC, games_count DESC, name ASC' do
        result = Player.with_stats_for_season(1).ranked

        expect(result.map(&:name)).to eq(%w[Charlie Bob Alice])
      end
    end

    context 'when players have equal totals' do
      let_it_be(:alice) { create(:player, name: 'Alice') }
      let_it_be(:bob) { create(:player, name: 'Bob') }
      let_it_be(:game) { create(:game, season: 1, series: 1, game_number: 1) }

      before do
        create(:rating, player: alice, game: game, plus: 2, minus: 0, win: true)
        create(:rating, player: bob, game: game, plus: 2, minus: 0, win: true)
      end

      it 'breaks ties on name ascending' do
        result = Player.with_stats_for_season(1).ranked

        expect(result.map(&:name)).to eq(%w[Alice Bob])
      end
    end
  end

  describe '.with_stats_for_season' do
    context 'when player has games in the season' do
      let_it_be(:player) { create(:player) }
      let_it_be(:game1) { create(:game, season: 1, series: 1, game_number: 1) }
      let_it_be(:game2) { create(:game, season: 1, series: 1, game_number: 2) }

      before do
        create(:rating, player: player, game: game1, plus: 3, minus: 1, win: true)
        create(:rating, player: player, game: game2, plus: 2, minus: 0, win: false)
      end

      it 'returns games_count, wins_count, and total_rating for the given season' do
        result = Player.with_stats_for_season(1).find(player.id)

        expect(result.games_count).to eq(2)
        expect(result.wins_count).to eq(1)
        expect(result.total_rating).to eq(4)
      end
    end

    context 'when player has games in multiple seasons' do
      let_it_be(:player) { create(:player) }
      let_it_be(:game_s1) { create(:game, season: 1, series: 1, game_number: 1) }
      let_it_be(:game_s2) { create(:game, season: 2, series: 1, game_number: 1) }

      before do
        create(:rating, player: player, game: game_s1, plus: 5, minus: 0, win: true)
        create(:rating, player: player, game: game_s2, plus: 10, minus: 0, win: true)
      end

      it 'excludes games from other seasons' do
        result = Player.with_stats_for_season(1).find(player.id)

        expect(result.games_count).to eq(1)
        expect(result.total_rating).to eq(5)
      end
    end

    context 'when plus and minus are nil' do
      let_it_be(:player) { create(:player) }
      let_it_be(:game) { create(:game, season: 1, series: 1, game_number: 1) }

      before do
        create(:rating, player: player, game: game, plus: nil, minus: nil, win: false)
      end

      it 'handles nil with COALESCE' do
        result = Player.with_stats_for_season(1).find(player.id)

        expect(result.total_rating).to eq(0)
      end
    end

    context 'when best_move is present' do
      let_it_be(:player) { create(:player) }
      let_it_be(:game) { create(:game, season: 1, series: 1, game_number: 1) }

      before do
        create(:rating, player: player, game: game, plus: 2, minus: 1, best_move: 0.5, win: true)
      end

      it 'includes best_move in total_rating' do
        result = Player.with_stats_for_season(1).find(player.id)

        expect(result.total_rating).to eq(1.5)
      end
    end
  end
end
