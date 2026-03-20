require "rails_helper"

RSpec.describe PlayerProfileService do
  describe ".call" do
    let_it_be(:player) { create(:player, name: "Алексей") }
    let_it_be(:game2) { create(:game, game_number: 2) }
    let_it_be(:game1) { create(:game, game_number: 1) }
    let_it_be(:game3) { create(:game, game_number: 1) }
    let_it_be(:participation2) { create(:game_participation, game: game2, player: player) }
    let_it_be(:participation1) { create(:game_participation, game: game1, player: player) }
    let_it_be(:participation3) { create(:game_participation, game: game3, player: player) }
    let_it_be(:award1) { create(:award, title: "Лучший игрок") }
    let_it_be(:award2) { create(:award, title: "Лучший стратег") }
    let_it_be(:player_award1) { create(:player_award, player: player, award: award1, position: 2) }
    let_it_be(:player_award2) { create(:player_award, player: player, award: award2, position: 1) }
    let(:result) { described_class.call(player_id: player.id) }

    it "returns a Result" do
      expect(result).to be_a(described_class::Result)
    end

    it "returns the player" do
      expect(result.player).to eq(player)
    end

    it "returns all player games" do
      expect(result.games).to match_array([ game1, game2, game3 ])
    end

    it "orders games by played_on, series, and game_number" do
      expect(result.games.last).to eq(game2)
    end

    it "returns an ActiveRecord relation of games" do
      expect(result.games).to be_an(ActiveRecord::Relation)
    end

    it "returns player awards ordered by position" do
      expect(result.player_awards).to eq([ player_award2, player_award1 ])
    end

    it "eager loads competition association on games" do
      loaded_games = result.games.load
      expect(loaded_games.first.association(:competition)).to be_loaded
    end

    it "eager loads competition parent association on games" do
      loaded_games = result.games.load
      competition = loaded_games.first.competition
      expect(competition.association(:parent)).to be_loaded
    end

    it "eager loads award association" do
      expect(result.player_awards.first.association(:award)).to be_loaded
    end

    it "returns a loaded relation for player_awards" do
      expect(result.player_awards).to be_loaded
    end

    it "returns news articles mentioning the player" do
      news_author = create(:user)
      news_article = create(:news, author: news_author, game: game1, status: :published, published_at: 1.day.ago)
      expect(result.news_articles).to include(news_article)
    end

    it "excludes draft news" do
      news_author = create(:user)
      create(:news, author: news_author, game: game1, status: :draft)
      expect(result.news_articles.select(&:draft?)).to be_empty
    end

    it "eager loads author association on news articles" do
      news_author = create(:user)
      create(:news, author: news_author, game: game1, status: :published, published_at: 1.day.ago)
      articles = result.news_articles.load
      expect(articles.first.association(:author)).to be_loaded
    end

    it "eager loads author player association on news articles" do
      claimed_player = create(:player)
      news_author = create(:user, player: claimed_player)
      create(:news, author: news_author, game: game1, status: :published, published_at: 1.day.ago)
      articles = result.news_articles.load
      expect(articles.first.author.association(:player)).to be_loaded
    end

    it "eager loads tags association on news articles" do
      news_author = create(:user)
      create(:news, author: news_author, game: game1, status: :published, published_at: 1.day.ago)
      articles = result.news_articles.load
      expect(articles.first.association(:tags)).to be_loaded
    end

    it "eager loads rich_text_content on news articles" do
      news_author = create(:user)
      create(:news, author: news_author, game: game1, status: :published, published_at: 1.day.ago)
      articles = result.news_articles.load
      expect(articles.first.association(:rich_text_content)).to be_loaded
    end

    context "when player has no games or awards" do
      let_it_be(:lonely_player) { create(:player, name: "Одинокий") }
      let(:lonely_result) { described_class.call(player_id: lonely_player.id) }

      it "returns empty games" do
        expect(lonely_result.games).to be_empty
      end

      it "returns empty player_awards" do
        expect(lonely_result.player_awards).to be_empty
      end

      it "returns empty news_articles" do
        expect(lonely_result.news_articles).to be_empty
      end
    end

    context "when player does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { described_class.call(player_id: -1) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
