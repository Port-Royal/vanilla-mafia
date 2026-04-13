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

    describe "content length" do
      let(:author) { create(:user) }

      it "allows content within the limit" do
        news = build(:news, author: author, content: "a" * 50_000)
        expect(news).to be_valid
      end

      it "rejects content exceeding the limit" do
        news = build(:news, author: author, content: "a" * 50_001)
        expect(news).not_to be_valid
        expect(news.errors.where(:content, :too_long)).to be_present
      end

      it "allows blank content" do
        news = build(:news, author: author)
        expect(news).to be_valid
      end
    end
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

  describe '.drafts_first' do
    let_it_be(:author) { create(:user) }
    let_it_be(:older) { create(:news, author:, published_at: 2.days.ago) }
    let_it_be(:newer) { create(:news, author:, published_at: 1.day.ago) }
    let_it_be(:draft) { create(:news, author:, published_at: nil) }

    it 'orders drafts first, then by published_at descending' do
      expect(described_class.drafts_first).to eq([ draft, newer, older ])
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

  describe ".visible" do
    let_it_be(:author) { create(:user) }
    let_it_be(:published_past) { create(:news, author:, status: :published, published_at: 1.day.ago) }
    let_it_be(:published_now) { create(:news, author:, status: :published, published_at: Time.current) }
    let_it_be(:published_future) { create(:news, author:, status: :published, published_at: 1.day.from_now) }
    let_it_be(:published_nil) { create(:news, author:, status: :published, published_at: nil) }
    let_it_be(:draft) { create(:news, author:, status: :draft) }

    it "includes published articles with published_at in the past" do
      expect(described_class.visible).to include(published_past)
    end

    it "includes published articles with published_at at current time" do
      expect(described_class.visible).to include(published_now)
    end

    it "excludes published articles with published_at in the future" do
      expect(described_class.visible).not_to include(published_future)
    end

    it "excludes published articles with nil published_at" do
      expect(described_class.visible).not_to include(published_nil)
    end

    it "excludes draft articles" do
      expect(described_class.visible).not_to include(draft)
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

    context 'with direct player mentions' do
      let_it_be(:directly_mentioned) { create(:news, author: author, status: :published, published_at: 4.days.ago) }

      before { NewsPlayerMention.find_or_create_by!(news: directly_mentioned, player: player) }

      it 'returns news articles with a direct mention even when they have no game' do
        expect(described_class.mentioning_player(player)).to include(directly_mentioned)
      end

      it 'excludes draft articles with direct mentions' do
        draft = create(:news, author: author, status: :draft)
        NewsPlayerMention.create!(news: draft, player: player)
        expect(described_class.mentioning_player(player)).not_to include(draft)
      end

      it 'does not duplicate articles that are both linked via game and directly mentioned' do
        NewsPlayerMention.create!(news: published_linked, player: player)
        result = described_class.mentioning_player(player)
        expect(result.count { |n| n == published_linked }).to eq(1)
      end

      it 'does not return articles that mention a different player' do
        other_mention = create(:news, author: author, status: :published, published_at: 6.days.ago)
        NewsPlayerMention.create!(news: other_mention, player: other_player)
        expect(described_class.mentioning_player(player)).not_to include(other_mention)
      end
    end
  end

  describe "#visible?" do
    let(:author) { create(:user) }

    it "returns true for published news with past published_at" do
      news = build(:news, :published, author:, published_at: 1.day.ago)
      expect(news).to be_visible
    end

    it "returns false for published news with future published_at" do
      news = build(:news, :published, author:, published_at: 1.day.from_now)
      expect(news).not_to be_visible
    end

    it "returns false for published news with nil published_at" do
      news = build(:news, author:, status: :published, published_at: nil)
      expect(news).not_to be_visible
    end

    it "returns false for draft news" do
      news = build(:news, author:)
      expect(news).not_to be_visible
    end
  end

  describe '#publish!' do
    let(:author) { create(:user) }

    context "when published_at is nil" do
      let(:news) { create(:news, author:) }

      it "sets status to published" do
        news.publish!

        expect(news.status).to eq("published")
      end

      it "sets published_at to current time" do
        news.publish!

        expect(news.published_at).to be_within(1.second).of(Time.current)
      end
    end

    context "when published_at is already set" do
      let(:scheduled_time) { 2.days.from_now }
      let(:news) { create(:news, author:, published_at: scheduled_time) }

      it "sets status to published" do
        news.publish!

        expect(news.status).to eq("published")
      end

      it "does not change published_at" do
        news.publish!

        expect(news.published_at).to be_within(1.second).of(scheduled_time)
      end
    end
  end

  describe "#truncated?" do
    let(:author) { create(:user) }

    it "returns false when content is blank" do
      news = build(:news, author: author)
      expect(news.truncated?(100)).to be false
    end

    it "returns false when content is within limit" do
      news = build(:news, author: author, content: "Short text")
      expect(news.truncated?(100)).to be false
    end

    it "returns true when content exceeds limit" do
      news = build(:news, author: author, content: "A" * 200)
      expect(news.truncated?(50)).to be true
    end
  end

  describe "#truncated_content" do
    let(:author) { create(:user) }

    it "returns content when within limit" do
      news = build(:news, author: author, content: "<p>Short.</p>")
      result = news.truncated_content(100)
      expect(result.to_plain_text).to include("Short.")
    end

    it "returns content when exactly at limit" do
      text = "Exact."
      news = build(:news, author: author, content: "<p>#{text}</p>")
      result = news.truncated_content(text.length)
      expect(result.to_plain_text).to include(text)
    end

    it "returns content when blank" do
      news = build(:news, author: author)
      expect(news.truncated_content(100)).to eq(news.content)
    end

    it "truncates at paragraph boundary" do
      news = build(:news, author: author, content: "<p>First paragraph.</p><p>Second paragraph.</p><p>Third paragraph.</p>")
      result = news.truncated_content(20)
      html = result.to_html
      expect(html).to include("First paragraph.")
      expect(html).not_to include("Third paragraph.")
    end

    it "keeps at least one paragraph even if it exceeds limit" do
      news = build(:news, author: author, content: "<p>This is a very long first paragraph that exceeds the limit.</p><p>Second.</p>")
      result = news.truncated_content(5)
      expect(result.to_html).to include("This is a very long first paragraph")
      expect(result.to_html).not_to include("Second.")
    end

    it "includes paragraphs up to the limit" do
      news = build(:news, author: author, content: "<p>AA</p><p>BB</p><p>CC</p>")
      result = news.truncated_content(4)
      expect(result.to_html).to include("AA")
      expect(result.to_html).to include("BB")
      expect(result.to_html).not_to include("CC")
    end
  end

  describe "slug" do
    let_it_be(:author) { create(:user) }

    describe "generation" do
      it "generates slug from published_at date and parameterized title" do
        news = create(:news, author:, title: "Breaking news about the game", status: :published, published_at: Time.zone.local(2026, 4, 12, 10, 0))
        expect(news.slug).to eq("2026-04-12-breaking-news-about-the-game")
      end

      it "transliterates cyrillic title to ascii" do
        news = create(:news, author:, title: "Важные новости о серии", status: :published, published_at: Time.zone.local(2026, 4, 12))
        expect(news.slug).to eq("2026-04-12-vazhnye-novosti-o-serii")
      end

      it "uses created_at when published_at is nil" do
        travel_to Time.zone.local(2026, 4, 10, 9, 30) do
          news = create(:news, author:, title: "Draft article", published_at: nil)
          expect(news.slug).to eq("2026-04-10-draft-article")
        end
      end

      it "truncates long titles to keep slug compact" do
        long_title = "word " * 40
        news = create(:news, author:, title: long_title, status: :published, published_at: Time.zone.local(2026, 4, 12))
        slug = news.slug
        title_part = slug.delete_prefix("2026-04-12-")
        expect(title_part.length).to be <= News::SLUG_TITLE_LIMIT
        expect(title_part).not_to end_with("-")
      end

      it "falls back to random hex when title has no latin/cyrillic characters" do
        news = create(:news, author:, title: "!!! ??? ...", status: :published, published_at: Time.zone.local(2026, 4, 12))
        expect(news.slug).to match(/\A2026-04-12-[a-f0-9]{4}\z/)
      end

      it "appends hex tail on collision" do
        create(:news, author:, title: "Duplicate title", status: :published, published_at: Time.zone.local(2026, 4, 12), slug: "2026-04-12-duplicate-title")
        news = build(:news, author:, title: "Duplicate title", status: :published, published_at: Time.zone.local(2026, 4, 12))
        news.valid?
        expect(news.slug).to start_with("2026-04-12-duplicate-title-")
        expect(news.slug.length).to eq("2026-04-12-duplicate-title-".length + 4)
      end

      it "does not change slug when title is updated" do
        news = create(:news, author:, title: "Original title", status: :published, published_at: Time.zone.local(2026, 4, 12))
        original_slug = news.slug
        news.update!(title: "Completely different title")
        expect(news.slug).to eq(original_slug)
      end
    end

    describe "#to_param" do
      it "returns the slug" do
        news = create(:news, author:, title: "Hello world", status: :published, published_at: Time.zone.local(2026, 4, 12))
        expect(news.to_param).to eq("2026-04-12-hello-world")
      end
    end
  end

  describe '#unpublish!' do
    let(:author) { create(:user) }
    let(:news) { create(:news, :published, author:) }

    it "sets status to draft" do
      news.unpublish!

      expect(news.status).to eq("draft")
    end

    it "does not change published_at" do
      original_published_at = news.published_at
      news.unpublish!

      expect(news.published_at).to eq(original_published_at)
    end
  end
end
