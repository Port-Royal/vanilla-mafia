require 'rails_helper'

RSpec.describe News, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:author).class_name("User") }
    it { is_expected.to belong_to(:game).optional }
    it { is_expected.to belong_to(:competition).optional }
    it { is_expected.to have_many(:taggings).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:taggings) }
    it { is_expected.to have_rich_text(:content) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to define_enum_for(:status).with_values(draft: "draft", published: "published").backed_by_column_of_type(:string) }
  end

  describe '.recent' do
    let_it_be(:author) { create(:user) }
    let_it_be(:older) { create(:news, author:, published_at: 2.days.ago) }
    let_it_be(:newer) { create(:news, author:, published_at: 1.day.ago) }
    let_it_be(:unpublished) { create(:news, author:, published_at: nil) }

    it 'orders by published_at descending with nulls last, then id descending' do
      expect(described_class.recent).to eq([ newer, older, unpublished ])
    end
  end

  describe '.for_game' do
    let_it_be(:game) { create(:game) }
    let_it_be(:author) { create(:user) }
    let_it_be(:linked) { create(:news, author:, game:) }
    let_it_be(:unlinked) { create(:news, author:) }

    it 'returns news for the given game' do
      expect(described_class.for_game(game)).to include(linked)
      expect(described_class.for_game(game)).not_to include(unlinked)
    end
  end

  describe '.for_competition' do
    let_it_be(:competition) { create(:competition, :series) }
    let_it_be(:other_competition) { create(:competition, :series) }
    let_it_be(:author) { create(:user) }
    let_it_be(:linked) { create(:news, author:, competition: competition) }
    let_it_be(:other) { create(:news, author:, competition: other_competition) }
    let_it_be(:unlinked) { create(:news, author:) }

    it 'returns news for the given competition' do
      result = described_class.for_competition(competition)
      expect(result).to include(linked)
      expect(result).not_to include(other, unlinked)
    end
  end

  describe '.by_author' do
    let_it_be(:author1) { create(:user) }
    let_it_be(:author2) { create(:user) }
    let_it_be(:news1) { create(:news, author: author1) }
    let_it_be(:news2) { create(:news, author: author2) }

    it 'returns news by the given author' do
      expect(described_class.by_author(author1)).to include(news1)
      expect(described_class.by_author(author1)).not_to include(news2)
    end
  end

  describe '.mentioning_player' do
    let_it_be(:author) { create(:user) }
    let_it_be(:player) { create(:player) }
    let_it_be(:other_player) { create(:player) }
    let_it_be(:game_with_player) { create(:game) }
    let_it_be(:game_without_player) { create(:game, game_number: 2) }
    let_it_be(:participation) { create(:game_participation, game: game_with_player, player: player) }
    let_it_be(:other_participation) { create(:game_participation, game: game_without_player, player: other_player) }
    let_it_be(:published_linked) { create(:news, author: author, game: game_with_player, status: :published, published_at: 1.day.ago) }
    let_it_be(:draft_linked) { create(:news, author: author, game: game_with_player, status: :draft) }
    let_it_be(:published_unlinked) { create(:news, author: author, game: game_without_player, status: :published, published_at: 2.days.ago) }
    let_it_be(:no_game) { create(:news, author: author, status: :published, published_at: 3.days.ago) }

    it 'returns published news linked to games the player participated in' do
      expect(described_class.mentioning_player(player)).to include(published_linked)
    end

    it 'excludes draft news' do
      expect(described_class.mentioning_player(player)).not_to include(draft_linked)
    end

    it 'excludes news for games the player did not participate in' do
      expect(described_class.mentioning_player(player)).not_to include(published_unlinked)
    end

    it 'excludes news without a game' do
      expect(described_class.mentioning_player(player)).not_to include(no_game)
    end

    it 'orders by published_at descending' do
      game2 = create(:game, game_number: 3)
      create(:game_participation, game: game2, player: player)
      older = create(:news, author: author, game: game2, status: :published, published_at: 5.days.ago)

      result = described_class.mentioning_player(player)
      expect(result.to_a).to eq([ published_linked, older ])
    end

    it 'does not return duplicates when player has multiple participations' do
      expect(described_class.mentioning_player(player).count).to eq(described_class.mentioning_player(player).distinct.count)
    end
  end

  describe '#publish!' do
    let(:author) { create(:user) }
    let(:news) { create(:news, author:) }

    it 'sets status to published and published_at' do
      news.publish!

      expect(news.status).to eq("published")
      expect(news.published_at).to be_within(1.second).of(Time.current)
    end
  end
end
