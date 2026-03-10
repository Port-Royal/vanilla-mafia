require 'rails_helper'

RSpec.describe News, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:author).class_name("User") }
    it { is_expected.to belong_to(:game).optional }
    it { is_expected.to have_many(:taggings).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:taggings) }
    it { is_expected.to have_rich_text(:content) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to define_enum_for(:status).with_values(draft: "draft", published: "published").backed_by_column_of_type(:string) }

    context "when season is present" do
      subject { build(:news, season: 1, series: nil) }

      it { is_expected.to validate_presence_of(:series) }
    end

    context "when series is present" do
      subject { build(:news, season: nil, series: 1) }

      it { is_expected.to validate_presence_of(:season) }
    end

    context "when both are blank" do
      subject { build(:news, season: nil, series: nil) }

      it { is_expected.to be_valid }
    end

    it { is_expected.to validate_numericality_of(:season).only_integer.allow_nil }
    it { is_expected.to validate_numericality_of(:series).only_integer.allow_nil }
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

  describe '.for_series' do
    let_it_be(:author) { create(:user) }
    let_it_be(:linked) { create(:news, author:, season: 1, series: 2) }
    let_it_be(:other_series) { create(:news, author:, season: 1, series: 3) }
    let_it_be(:unlinked) { create(:news, author:) }

    it 'returns news for the given season and series' do
      result = described_class.for_series(1, 2)
      expect(result).to include(linked)
      expect(result).not_to include(other_series, unlinked)
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
