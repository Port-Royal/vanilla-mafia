require "rails_helper"

RSpec.describe HomeController do
  describe "GET /" do
    before { get root_path }

    it "returns success" do
      expect(response).to have_http_status(:ok)
    end

    it "does not redirect" do
      expect(response).not_to have_http_status(:redirect)
    end

    it "renders within the application layout" do
      expect(response.body).to include("Vanilla Mafia")
    end
  end

  describe "hero section" do
    before { get root_path }

    it "renders the club logo" do
      expect(response.body).to include('src="/img/chi_light.png"')
    end

    it "renders the club name" do
      expect(response.body).to include(I18n.t("home.hero.title"))
    end

    it "renders the tagline" do
      expect(response.body).to include(I18n.t("home.hero.tagline"))
    end

    context "when a running competition exists" do
      let_it_be(:competition) { create(:competition, :season, name: "Season 7", ended_on: nil) }

      before { get root_path }

      it "renders the CTA button linking to the current tournament" do
        expect(response.body).to include(competition_path(slug: competition.slug))
      end

      it "renders the CTA button text" do
        expect(response.body).to include(I18n.t("home.hero.cta"))
      end
    end

    context "when no running competition exists" do
      before { get root_path }

      it "does not render the CTA button" do
        expect(response.body).not_to include(I18n.t("home.hero.cta"))
      end
    end
  end

  describe "running tournaments block" do
    context "when running competitions with players exist" do
      let_it_be(:competition) { create(:competition, :season, name: "Season 6", ended_on: nil) }
      let_it_be(:child) { create(:competition, :series, parent: competition, name: "Series 1") }
      let_it_be(:role) { create(:role) }
      let_it_be(:players) do
        (1..6).map { |i| create(:player, name: "Player #{i}") }
      end
      let_it_be(:game) { create(:game, competition: child) }

      before_all do
        players.each_with_index do |player, i|
          create(:game_participation, game: game, player: player, role: role, plus: 10 - i)
        end
      end

      before { get root_path }

      it "renders the section title" do
        expect(response.body).to include(I18n.t("home.running_tournaments.running_tournaments"))
      end

      it "renders the competition name" do
        expect(response.body).to include("Season 6")
      end

      it "renders a link to the competition page" do
        expect(response.body).to include(competition_path(slug: competition.slug))
      end

      it "renders top 5 players" do
        (1..5).each do |i|
          expect(response.body).to include("Player #{i}")
        end
      end

      it "does not render the 6th player" do
        expect(response.body).not_to include("Player 6")
      end

      it "renders player ratings" do
        expect(response.body).to include("10.0")
      end

      it "ranks players by rating descending" do
        body = response.body
        pos_player1 = body.index("Player 1")
        pos_player5 = body.index("Player 5")
        expect(pos_player1).to be < pos_player5
      end
    end

    context "when only child competitions are running" do
      let_it_be(:parent) { create(:competition, :season, name: "Parent Season", ended_on: nil) }
      let_it_be(:child_running) { create(:competition, :series, parent: parent, name: "Child Series", ended_on: nil) }

      before { get root_path }

      it "shows root competitions only" do
        expect(response.body).to include("Parent Season")
        expect(response.body).not_to include("Child Series")
      end
    end

    context "when multiple running competitions exist" do
      let_it_be(:second) { create(:competition, :season, name: "Second Comp", ended_on: nil, position: 2) }
      let_it_be(:first) { create(:competition, :season, name: "First Comp", ended_on: nil, position: 1) }

      before { get root_path }

      it "orders competitions by position" do
        body = response.body
        pos_first = body.index("First Comp")
        pos_second = body.index("Second Comp")
        expect(pos_first).to be < pos_second
      end
    end

    context "when no running competitions exist" do
      let_it_be(:finished) { create(:competition, :season, name: "Season 5", ended_on: Date.new(2025, 12, 31)) }

      before { get root_path }

      it "does not render the running tournaments section" do
        expect(response.body).not_to include(I18n.t("home.running_tournaments.running_tournaments"))
      end
    end

    context "when a running competition has no games yet" do
      let_it_be(:empty_competition) { create(:competition, :season, name: "Empty Season", ended_on: nil) }

      before { get root_path }

      it "renders the competition name" do
        expect(response.body).to include("Empty Season")
      end

      it "does not render a standings table for it" do
        expect(response.body).not_to include("<table")
      end
    end
  end

  describe "recently finished tournaments block" do
    context "when recently finished competitions exist" do
      let_it_be(:role) { create(:role) }
      let_it_be(:finished_comp) do
        create(:competition, :season, name: "Season 5", ended_on: Date.new(2026, 3, 1))
      end
      let_it_be(:child) { create(:competition, :series, parent: finished_comp, name: "Series F1") }
      let_it_be(:winner) { create(:player, name: "Champion Alice") }
      let_it_be(:runner_up) { create(:player, name: "Runner Bob") }
      let_it_be(:game) { create(:game, competition: child) }

      before_all do
        create(:game_participation, game: game, player: winner, role: role, plus: 20)
        create(:game_participation, game: game, player: runner_up, role: role, plus: 10)
      end

      before { get root_path }

      it "renders the section title" do
        expect(response.body).to include(I18n.t("home.recently_finished.title"))
      end

      it "renders the competition name" do
        expect(response.body).to include("Season 5")
      end

      it "renders a link to the competition page" do
        expect(response.body).to include(competition_path(slug: finished_comp.slug))
      end

      it "renders the winner name" do
        expect(response.body).to include("Champion Alice")
      end
    end

    context "when more than 3 finished competitions exist" do
      let_it_be(:comps) do
        (1..4).map do |i|
          create(:competition, :season, name: "Finished #{i}", ended_on: Date.new(2026, i, 1))
        end
      end

      before { get root_path }

      it "shows only the 3 most recent" do
        expect(response.body).to include("Finished 4")
        expect(response.body).to include("Finished 3")
        expect(response.body).to include("Finished 2")
      end

      it "does not show the oldest" do
        expect(response.body).not_to include("Finished 1")
      end
    end

    context "when competitions are ordered by ended_on" do
      let_it_be(:older) { create(:competition, :season, name: "Older Comp", ended_on: Date.new(2025, 6, 1)) }
      let_it_be(:newer) { create(:competition, :season, name: "Newer Comp", ended_on: Date.new(2026, 1, 1)) }

      before { get root_path }

      it "renders newer competition before older" do
        body = response.body
        pos_newer = body.index("Newer Comp")
        pos_older = body.index("Older Comp")
        expect(pos_newer).not_to be_nil
        expect(pos_older).not_to be_nil
        expect(pos_newer).to be < pos_older
      end
    end

    context "when no finished competitions exist" do
      before { get root_path }

      it "does not render the recently finished section" do
        expect(response.body).not_to include(I18n.t("home.recently_finished.title"))
      end
    end

    context "when a finished competition has no games" do
      let_it_be(:empty_finished) { create(:competition, :season, name: "Empty Finished", ended_on: Date.new(2026, 2, 1)) }

      before { get root_path }

      it "renders the competition name" do
        expect(response.body).to include("Empty Finished")
      end
    end
  end

  describe "recent games block" do
    context "when games exist" do
      let_it_be(:competition) { create(:competition, :season, name: "Season 8", ended_on: nil) }
      let_it_be(:child) { create(:competition, :series, parent: competition, name: "Series 1") }
      let_it_be(:game) do
        create(:game, competition: child, played_on: Date.new(2026, 3, 20),
               result: "peace_victory", judge: "Judge Judy", game_number: 1)
      end

      before { get root_path }

      it "renders the section title" do
        expect(response.body).to include(I18n.t("home.recent_games.title"))
      end

      it "renders a link to the game page" do
        expect(response.body).to include(game_path(game))
      end

      it "renders the game result" do
        expect(response.body).to include(I18n.t("activerecord.attributes.game.results.peace_victory"))
      end

      it "renders the judge name" do
        expect(response.body).to include("Judge Judy")
      end

      it "renders the played_on date" do
        expect(response.body).to include(I18n.l(game.played_on, format: :short))
      end
    end

    context "when more than 5 games exist" do
      let_it_be(:competition) { create(:competition, :season, name: "Season 9", ended_on: nil) }
      let_it_be(:child) { create(:competition, :series, parent: competition, name: "Series G") }
      let_it_be(:games) do
        (1..6).map do |i|
          create(:game, competition: child, played_on: Date.new(2026, 3, i),
                 result: "peace_victory", game_number: i)
        end
      end

      before { get root_path }

      it "shows only the 5 most recent" do
        (2..6).each do |i|
          expect(response.body).to include(game_path(games[i - 1]))
        end
      end

      it "does not show the oldest game" do
        expect(response.body).not_to include(game_path(games[0]))
      end
    end

    context "when games are ordered by played_on" do
      let_it_be(:competition) { create(:competition, :season, name: "Season 10", ended_on: nil) }
      let_it_be(:child) { create(:competition, :series, parent: competition, name: "Series O") }
      let_it_be(:older_game) { create(:game, competition: child, played_on: Date.new(2026, 1, 1), result: "peace_victory", game_number: 1) }
      let_it_be(:newer_game) { create(:game, competition: child, played_on: Date.new(2026, 3, 1), result: "mafia_victory", game_number: 2) }

      before { get root_path }

      it "renders newer game before older" do
        body = response.body
        pos_newer = body.index(game_path(newer_game))
        pos_older = body.index(game_path(older_game))
        expect(pos_newer).not_to be_nil
        expect(pos_older).not_to be_nil
        expect(pos_newer).to be < pos_older
      end
    end

    context "when only in_progress games exist" do
      let_it_be(:competition) { create(:competition, :season, name: "Season IP", ended_on: nil) }
      let_it_be(:child) { create(:competition, :series, parent: competition, name: "Series IP") }
      let_it_be(:game) do
        create(:game, competition: child, played_on: Date.new(2026, 3, 25),
               result: "in_progress", game_number: 1)
      end

      before { get root_path }

      it "does not render the recent games section" do
        expect(response.body).not_to include(I18n.t("home.recent_games.title"))
      end
    end

    context "when no games exist" do
      before { get root_path }

      it "does not render the recent games section" do
        expect(response.body).not_to include(I18n.t("home.recent_games.title"))
      end
    end
  end

  describe "latest news block" do
    context "when published news exist" do
      let_it_be(:article) do
        create(:news, :published, title: "Big Tournament Recap")
      end

      before { get root_path }

      it "renders the section title" do
        expect(response.body).to include(I18n.t("home.latest_news.title"))
      end

      it "renders the article title" do
        expect(response.body).to include("Big Tournament Recap")
      end

      it "renders a link to the article" do
        expect(response.body).to include(news_path(article))
      end

      it "renders the published date" do
        expect(response.body).to include(I18n.l(article.published_at.to_date, format: :short))
      end

      it "renders a link to the news index" do
        expect(response.body).to include(news_index_path)
      end
    end

    context "when more than 3 published news exist" do
      let_it_be(:articles) do
        (1..4).map do |i|
          create(:news, :published, title: "Article #{i}",
                 published_at: Time.zone.local(2026, 3, i))
        end
      end

      before { get root_path }

      it "shows only the 3 most recent" do
        expect(response.body).to include("Article 4")
        expect(response.body).to include("Article 3")
        expect(response.body).to include("Article 2")
      end

      it "does not show the oldest" do
        expect(response.body).not_to include("Article 1")
      end
    end

    context "when only draft news exist" do
      let_it_be(:draft) { create(:news, title: "Draft Article") }

      before { get root_path }

      it "does not render the latest news section" do
        expect(response.body).not_to include(I18n.t("home.latest_news.title"))
      end
    end

    context "when no news exist" do
      before { get root_path }

      it "does not render the latest news section" do
        expect(response.body).not_to include(I18n.t("home.latest_news.title"))
      end
    end
  end
end
