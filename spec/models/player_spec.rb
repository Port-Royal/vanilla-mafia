require 'rails_helper'

RSpec.describe Player, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:ratings).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:games).through(:ratings) }
    it { is_expected.to have_many(:player_awards).dependent(:destroy) }
    it { is_expected.to have_many(:awards).through(:player_awards) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe '.ordered' do
    it 'orders by position ascending then name ascending' do
      charlie = create(:player, name: 'Charlie', position: 2)
      alice = create(:player, name: 'Alice', position: 1)
      bob = create(:player, name: 'Bob', position: 1)

      expect(described_class.ordered).to eq([ alice, bob, charlie ])
    end
  end

  describe '.ranked' do
    it 'orders by total_rating DESC, wins_count DESC, games_count DESC, name ASC' do
      alice = create(:player, name: 'Alice')
      bob = create(:player, name: 'Bob')
      charlie = create(:player, name: 'Charlie')

      game1 = create(:game, season: 1, series: 1, game_number: 1)
      game2 = create(:game, season: 1, series: 1, game_number: 2)

      # Alice: total_rating=2, wins=1, games=1
      create(:rating, player: alice, game: game1, plus: 3, minus: 1, win: true)
      # Bob: total_rating=2, wins=1, games=2
      create(:rating, player: bob, game: game1, plus: 1, minus: 0, win: true)
      create(:rating, player: bob, game: game2, plus: 1, minus: 0, win: false)
      # Charlie: total_rating=5, wins=1, games=1
      create(:rating, player: charlie, game: game2, plus: 5, minus: 0, win: true)

      result = Player.with_stats_for_season(1).ranked

      expect(result.map(&:name)).to eq(%w[Charlie Bob Alice])
    end

    it 'breaks ties on name ascending' do
      alice = create(:player, name: 'Alice')
      bob = create(:player, name: 'Bob')

      game = create(:game, season: 1, series: 1, game_number: 1)
      create(:rating, player: alice, game: game, plus: 2, minus: 0, win: true)
      create(:rating, player: bob, game: game, plus: 2, minus: 0, win: true)

      result = Player.with_stats_for_season(1).ranked

      expect(result.map(&:name)).to eq(%w[Alice Bob])
    end
  end

  describe '.with_stats_for_season' do
    it 'returns games_count, wins_count, and total_rating for the given season' do
      player = create(:player)
      game1 = create(:game, season: 1, series: 1, game_number: 1)
      game2 = create(:game, season: 1, series: 1, game_number: 2)
      create(:rating, player: player, game: game1, plus: 3, minus: 1, win: true)
      create(:rating, player: player, game: game2, plus: 2, minus: 0, win: false)

      result = Player.with_stats_for_season(1).find(player.id)

      expect(result.games_count).to eq(2)
      expect(result.wins_count).to eq(1)
      expect(result.total_rating).to eq(4)
    end

    it 'excludes games from other seasons' do
      player = create(:player)
      game_s1 = create(:game, season: 1, series: 1, game_number: 1)
      game_s2 = create(:game, season: 2, series: 1, game_number: 1)
      create(:rating, player: player, game: game_s1, plus: 5, minus: 0, win: true)
      create(:rating, player: player, game: game_s2, plus: 10, minus: 0, win: true)

      result = Player.with_stats_for_season(1).find(player.id)

      expect(result.games_count).to eq(1)
      expect(result.total_rating).to eq(5)
    end

    it 'handles nil plus/minus with COALESCE' do
      player = create(:player)
      game = create(:game, season: 1, series: 1, game_number: 1)
      create(:rating, player: player, game: game, plus: nil, minus: nil, win: false)

      result = Player.with_stats_for_season(1).find(player.id)

      expect(result.total_rating).to eq(0)
    end
  end
end
