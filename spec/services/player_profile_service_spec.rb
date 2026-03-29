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

    it "returns competitions_with_games grouped by root competition" do
      root = game1.competition.root
      expect(result.competitions_with_games).to be_an(Array)
      expect(result.competitions_with_games.first).to be_a(described_class::CompetitionGames)
      expect(result.competitions_with_games.map(&:competition)).to include(root)
    end

    it "includes all games under their root competition" do
      all_games = result.competitions_with_games.flat_map(&:games)
      expect(all_games).to match_array([ game1, game2, game3 ])
    end

    describe "grouping by root competition" do
      let_it_be(:root_player) { create(:player, name: "Группировщик") }
      let_it_be(:season) { create(:competition, :season) }
      let_it_be(:series1) { create(:competition, :series, parent: season) }
      let_it_be(:series2) { create(:competition, :series, parent: season) }
      let_it_be(:root_game1) { create(:game, competition: series1, game_number: 1) }
      let_it_be(:root_game2) { create(:game, competition: series2, game_number: 1) }

      before do
        create(:game_participation, game: root_game1, player: root_player)
        create(:game_participation, game: root_game2, player: root_player)
      end

      it "groups games from child competitions under their root" do
        root_result = described_class.call(player_id: root_player.id)
        expect(root_result.competitions_with_games.size).to eq(1)
        expect(root_result.competitions_with_games.first.competition).to eq(season)
        expect(root_result.competitions_with_games.first.games).to match_array([ root_game1, root_game2 ])
      end
    end

    describe "competition ordering" do
      let_it_be(:order_player) { create(:player, name: "Сортировщик") }
      let_it_be(:old_comp) { create(:competition, :season, started_on: Date.new(2024, 1, 1)) }
      let_it_be(:new_comp) { create(:competition, :season, started_on: Date.new(2025, 6, 1)) }
      let_it_be(:old_game) { create(:game, competition: old_comp, game_number: 1) }
      let_it_be(:new_game) { create(:game, competition: new_comp, game_number: 1) }

      before do
        create(:game_participation, game: old_game, player: order_player)
        create(:game_participation, game: new_game, player: order_player)
      end

      it "orders competitions by started_on descending" do
        order_result = described_class.call(player_id: order_player.id)
        competitions = order_result.competitions_with_games.map(&:competition)
        expect(competitions).to eq([ new_comp, old_comp ])
      end
    end

    describe "game ordering within competition" do
      let_it_be(:shared_comp) { create(:competition, :series) }
      let_it_be(:ordering_player) { create(:player, name: "Порядочный") }
      let_it_be(:late_game) { create(:game, competition: shared_comp, game_number: 2, played_on: Date.new(2025, 2, 1)) }
      let_it_be(:early_game) { create(:game, competition: shared_comp, game_number: 1, played_on: Date.new(2025, 1, 1)) }

      before do
        create(:game_participation, game: late_game, player: ordering_player)
        create(:game_participation, game: early_game, player: ordering_player)
      end

      it "orders games by played_on and game_number" do
        ordering_result = described_class.call(player_id: ordering_player.id)
        entry = ordering_result.competitions_with_games.first
        expect(entry.games).to eq([ early_game, late_game ])
      end
    end

    it "returns player awards ordered by position" do
      expect(result.player_awards).to eq([ player_award2, player_award1 ])
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

    describe "stats" do
      let_it_be(:stats_player) { create(:player, name: "Статистик") }
      let_it_be(:peace_role) { Role.find_or_create_by!(code: "peace") { |r| r.name = "Мирный" } }
      let_it_be(:mafia_role) { Role.find_or_create_by!(code: "mafia") { |r| r.name = "Мафия" } }
      let_it_be(:sheriff_role) { Role.find_or_create_by!(code: "sheriff") { |r| r.name = "Шериф" } }
      let_it_be(:stats_game1) { create(:game, game_number: 1, result: :peace_victory, played_on: Date.new(2024, 6, 15)) }
      let_it_be(:stats_game2) { create(:game, game_number: 2, result: :mafia_victory, played_on: Date.new(2024, 3, 1)) }
      let_it_be(:stats_game3) { create(:game, game_number: 3, result: :peace_victory, played_on: Date.new(2025, 1, 10)) }

      before do
        create(:game_participation, game: stats_game1, player: stats_player, role: peace_role, win: true)
        create(:game_participation, game: stats_game2, player: stats_player, role: mafia_role, win: true)
        create(:game_participation, game: stats_game3, player: stats_player, role: peace_role, win: false)
      end

      let(:stats) { described_class.call(player_id: stats_player.id).stats }

      it "returns total games count" do
        expect(stats.total_games).to eq(3)
      end

      it "returns total wins count" do
        expect(stats.total_wins).to eq(2)
      end

      it "returns win rate as percentage" do
        expect(stats.win_rate).to eq(66.7)
      end

      it "returns earliest game date regardless of order" do
        expect(stats.first_game_date).to eq(Date.new(2024, 3, 1))
      end

      it "returns role stats for each role played" do
        expect(stats.role_stats).to contain_exactly(
          have_attributes(role_code: "peace", role_name: "Мирный", games: 2, wins: 1, win_rate: 50.0),
          have_attributes(role_code: "mafia", role_name: "Мафия", games: 1, wins: 1, win_rate: 100.0)
        )
      end

      it "orders role stats by games count descending" do
        expect(stats.role_stats.first.role_code).to eq("peace")
      end

      context "when player has no games" do
        let_it_be(:no_games_player) { create(:player, name: "Новичок") }
        let(:empty_stats) { described_class.call(player_id: no_games_player.id).stats }

        it "returns zero total games" do
          expect(empty_stats.total_games).to eq(0)
        end

        it "returns zero win rate" do
          expect(empty_stats.win_rate).to eq(0.0)
        end

        it "returns nil first game date" do
          expect(empty_stats.first_game_date).to be_nil
        end

        it "returns empty role stats" do
          expect(empty_stats.role_stats).to be_empty
        end
      end
    end

    context "when player has no games or awards" do
      let_it_be(:lonely_player) { create(:player, name: "Одинокий") }
      let(:lonely_result) { described_class.call(player_id: lonely_player.id) }

      it "returns empty competitions_with_games" do
        expect(lonely_result.competitions_with_games).to be_empty
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
