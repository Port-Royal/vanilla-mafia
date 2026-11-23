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
        assert_select "#home-running", count: 0
      end
    end

    context "when a running competition has no games yet" do
      let_it_be(:empty_competition) { create(:competition, :season, name: "Empty Season", ended_on: nil) }

      before { get root_path }

      it "renders the competition name" do
        expect(response.body).to include("Empty Season")
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
        assert_select "#home-recently-finished", count: 0
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
    context "when a recent game is a draw" do
      let_it_be(:competition) { create(:competition, :season, name: "Season 9", ended_on: nil) }
      let_it_be(:child) { create(:competition, :series, parent: competition, name: "Series 1") }
      let_it_be(:game) do
        create(:game, competition: child, played_on: Date.new(2026, 3, 20), result: "draw", game_number: 1)
      end

      before { get root_path }

      it "renders the draw label" do
        expect(response.body).to include(I18n.t("activerecord.attributes.game.results.draw"))
      end
    end

    context "when games exist" do
      let_it_be(:competition) { create(:competition, :season, name: "Season 8", ended_on: nil) }
      let_it_be(:child) { create(:competition, :series, parent: competition, name: "Series 1") }
      let_it_be(:game) do
        create(:game, competition: child, played_on: Date.new(2026, 3, 20),
               result: "peace_victory", judge: "Judge Judy", game_number: 1)
      end

      before { get root_path }

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
        expect(response.body).to include(DatetimeFormatter.call(game.played_on, type: :date))
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

      it "renders the article title" do
        expect(response.body).to include("Big Tournament Recap")
      end

      it "renders the article title as plain text" do
        assert_select "h3", text: /Big Tournament Recap/
      end

      it "renders the published date" do
        expect(response.body).to include(DatetimeFormatter.call(article.published_at, type: :date))
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
        assert_select "#home-news", count: 0
      end
    end

    context "when no news exist" do
      before { get root_path }

      it "does not render the latest news section" do
        assert_select "#home-news", count: 0
      end
    end
  end
end

RSpec.describe "Home page" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:main) { document.at_css("main#site-main") }
  let(:columns) { document.at_css("#home-columns") }
  let(:results) { document.at_css("#home-results") }
  let(:news_column) { document.at_css("#home-news") }
  let(:running) { document.at_css("#home-running") }
  let(:recently_finished) { document.at_css("#home-recently-finished") }
  let(:recent_games) { document.at_css("#home-recent-games") }
  let(:two_columns_class) { "lg:grid-cols-[11fr_9fr]" }

  context "with results and news" do
    let_it_be(:role) { create(:role) }
    let_it_be(:season) { create(:competition, :season, name: "Season 6", ended_on: nil) }
    let_it_be(:series) { create(:competition, :series, parent: season, name: "Series 3") }
    let_it_be(:players) { (1..6).map { |i| create(:player, name: "Player #{i}") } }
    let_it_be(:game) do
      create(:game, competition: series, played_on: Date.new(2026, 3, 20), result: "peace_victory",
                    judge: "Judge Judy", game_number: 14)
    end
    let_it_be(:finished_season) { create(:competition, :season, name: "Season 5", ended_on: Date.new(2026, 3, 1)) }
    let_it_be(:finished_series) { create(:competition, :series, parent: finished_season, name: "Series F") }
    let_it_be(:finished_game) do
      create(:game, competition: finished_series, played_on: Date.new(2026, 2, 1), result: "mafia_victory",
                    game_number: 2)
    end
    let_it_be(:runner_up) { create(:player, name: "Runner Bob") }
    let_it_be(:champion) { create(:player, name: "Champion Alice") }
    let_it_be(:article) do
      create(:news, :published, title: "Big Recap", content: "<p>Twelve players and <strong>eight</strong> games</p>",
                                published_at: Time.zone.local(2026, 3, 21, 12))
    end

    before_all do
      players.each_with_index do |player, i|
        create(:game_participation, game: game, player: player, role: role, plus: i + 1)
      end
      create(:game_participation, game: finished_game, player: runner_up, role: role, plus: 1)
      create(:game_participation, game: finished_game, player: champion, role: role, plus: 5)
    end

    describe "heading" do
      before { get root_path }

      it { expect(main.css("h1").size).to eq(1) }
      it { expect(main.at_css("h1")["class"].split).to eq(%w[sr-only]) }
      it { expect(main.at_css("h1").text).to eq(I18n.t("home.hero.title")) }
    end

    describe "columns" do
      before { get root_path }

      it { expect(columns["class"].split).to include("grid", two_columns_class) }
      it { expect(columns.element_children.map { |child| child["id"] }).to eq(%w[home-results home-news]) }
    end

    describe "running now" do
      let(:panel) { running.at_css(".vm-panel") }
      let(:rows) { panel.css("tbody tr") }
      let(:competition_links) { panel.css("a[href='#{competition_path(slug: season.slug)}']") }
      let(:table_link) { competition_links.last }

      before { get root_path }

      it { expect(running.at_css(".vm-label").text).to eq(I18n.t("home.redesign.running")) }
      it { expect(panel.at_css("a[href='#{competition_path(slug: season.slug)}']").text.strip).to eq("Season 6") }
      it { expect(competition_links.size).to eq(2) }
      it { expect(table_link.text.strip).to start_with(I18n.t("home.redesign.table_link")) }
      it { expect(table_link.at_css("span[aria-hidden='true']").text).to eq("→") }
      it { expect(table_link["aria-label"]).to eq(I18n.t("home.redesign.table_link_label", competition: "Season 6")) }
      it { expect(panel.at_css("table")["class"]).to include("vm-table") }
      it { expect(rows.map { |row| row.at_css("a").text }).to eq([ "Player 6", "Player 5", "Player 4", "Player 3", "Player 2" ]) }
      it { expect(rows.first.at_css("a")["href"]).to eq(player_path(players.last)) }
      it { expect(rows.map { |row| row.at_css(".vm-medal").text }).to eq(%w[1 2 3 4 5]) }
      it { expect(rows.first.at_css(".vm-medal")["class"].split).to include("vm-medal--1") }
      it { expect(rows[1].at_css(".vm-medal")["class"].split).to include("vm-medal--2") }
      it { expect(rows[2].at_css(".vm-medal")["class"].split).to include("vm-medal--3") }
      it { expect(rows[3].at_css(".vm-medal")["class"].split).to contain_exactly("vm-medal", "text-ink-muted") }
      it { expect(rows.first.css("td").last.text.strip).to eq("6.0") }
      it { expect(rows.first.css("td").last["class"].split).to include("text-right", "tabular-nums") }

      context "when a running competition has no players yet" do
        let_it_be(:empty_season) { create(:competition, :season, name: "Empty Season", ended_on: nil, position: 99) }

        let(:empty_panel) { running.css(".vm-panel").last }

        it { expect(response).to have_http_status(:ok) }
        it { expect(empty_panel.text).to include("Empty Season") }
        it { expect(empty_panel.css("tbody tr")).to be_empty }
      end
    end

    describe "recently finished" do
      let(:rows) { recently_finished.css("li") }

      before { get root_path }

      it { expect(recently_finished.at_css(".vm-label").text).to eq(I18n.t("home.redesign.recently_finished")) }
      it { expect(rows.first.at_css("a[href='#{competition_path(slug: finished_season.slug)}']").text).to eq("Season 5") }
      it { expect(rows.first.text).to include(DatetimeFormatter.call(finished_season.ended_on, type: :date)) }
      it { expect(rows.first.text).to include(I18n.t("home.redesign.winner")) }
      it { expect(rows.first.at_css("a[href='#{player_path(champion)}']").text).to eq("Champion Alice") }
      it { expect(rows.first.at_css("a[href='#{player_path(champion)}']")["class"].split).to include("decoration-gold-line") }

      context "when a finished competition has no games" do
        let_it_be(:empty_finished) { create(:competition, :season, name: "Empty Finished", ended_on: Date.new(2026, 4, 1)) }

        it { expect(rows.first.text).to include("Empty Finished") }
        it { expect(rows.first.text).not_to include(I18n.t("home.redesign.winner")) }
      end

      context "when a child competition has finished" do
        let_it_be(:finished_child) do
          create(:competition, :series, parent: season, name: "Finished Child", ended_on: Date.new(2026, 4, 1))
        end

        it { expect(recently_finished.text).not_to include("Finished Child") }
      end

      context "when more than three competitions have finished" do
        let_it_be(:more_finished) do
          (1..3).map { |i| create(:competition, :season, name: "Later #{i}", ended_on: Date.new(2026, 4, i)) }
        end

        it { expect(rows.map { |row| row.at_css("a").text }).to eq([ "Later 3", "Later 2", "Later 1" ]) }
      end
    end

    describe "recent games" do
      let(:rows) { recent_games.css("li") }
      let(:game_row) { rows.find { |row| row.at_css("a[href='#{game_path(game)}']") } }

      before { get root_path }

      it { expect(recent_games.at_css(".vm-label").text).to eq(I18n.t("home.recent_games.title")) }
      it { expect(rows.size).to eq(2) }
      it { expect(game_row.at_css("a").text).to eq("#{I18n.t('common.game')} 14") }
      it { expect(game_row.text).to include("Series 3") }
      it { expect(game_row.text).to include(DatetimeFormatter.call(game.played_on, type: :date)) }
      it { expect(game_row.text).to include("Judge Judy") }
      it { expect(game_row.at_css(".vm-pill--gold").text).to eq(I18n.t("activerecord.attributes.game.results.peace_victory")) }
      it { expect(rows.last.at_css(".vm-pill--alert")).to be_present }
    end

    describe "news" do
      let(:items) { news_column.css("article") }
      let(:item) { items.first }
      let(:all_news_link) { news_column.at_css("a[href='#{news_index_path}']") }

      before { get root_path }

      it { expect(news_column.at_css(".vm-label").text).to eq(I18n.t("home.redesign.news")) }
      it { expect(all_news_link.text.strip).to eq(I18n.t("home.latest_news.all_news")) }
      it { expect(all_news_link["class"].split).to include("decoration-gold-line") }
      it { expect(item.at_css("h3 > a[href='#{news_path(article)}']").text).to eq("Big Recap") }
      it { expect(item.text).to include(DatetimeFormatter.call(article.published_at, type: :date)) }
      it { expect(item.at_css("p").text.strip).to eq("Twelve players and eight games") }
      it { expect(item.at_css("p strong")).to be_nil }
      it { expect(item.at_css("img")).to be_nil }

      context "when the article text is long" do
        let_it_be(:long_article) do
          create(:news, :published, title: "Long Read", content: "<p>#{'word ' * 100}</p>",
                                    published_at: Time.zone.local(2026, 3, 22))
        end

        it { expect(item.at_css("p").text.strip).to end_with("…") }
        it { expect(item.at_css("p").text.length).to be <= 160 }
      end

      context "when more than three articles are visible" do
        let_it_be(:more_articles) do
          (1..3).map { |i| create(:news, :published, title: "Later #{i}", published_at: Time.zone.local(2026, 4, i)) }
        end

        it { expect(items.map { |entry| entry.at_css("a").text }).to eq([ "Later 3", "Later 2", "Later 1" ]) }
      end

      context "when a newer article is a draft" do
        let_it_be(:draft) { create(:news, title: "Draft Recap", published_at: Time.zone.local(2026, 4, 1)) }

        it { expect(news_column.text).not_to include("Draft Recap") }
      end

      context "when the author is a claimed player" do
        let_it_be(:author_player) { create(:player, name: "Writer Wren") }
        let_it_be(:claimed_article) do
          create(:news, :published, title: "By a player", author: create(:user, player: author_player),
                                    published_at: Time.zone.local(2026, 3, 23))
        end

        it { expect(item.text).to include("Writer Wren") }
      end

      context "when the article has a photo" do
        let_it_be(:photo_article) do
          create(:news, :published, :with_photo, title: "With photo", published_at: Time.zone.local(2026, 3, 23))
        end

        let(:card_path) do
          rails_representation_path(photo_article.photos.first.variant(NewsHelper::NEWS_PHOTO_VARIANTS[:card]), only_path: true)
        end

        it { expect(item.at_css("img")["src"]).to end_with(card_path) }
      end

      context "when the article has only an attachment that cannot be resized" do
        let_it_be(:pdf_article) do
          create(:news, :published, title: "With a PDF", published_at: Time.zone.local(2026, 3, 23)).tap do |news|
            blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4"), filename: "rules.pdf",
                                                          content_type: "application/pdf")
            ActiveStorage::Attachment.create!(name: "photos", record: news, blob: blob)
          end
        end

        it { expect(response).to have_http_status(:ok) }
        it { expect(item.at_css("a").text).to eq("With a PDF") }
        it { expect(item.at_css("img")).to be_nil }
      end
    end

    describe "database queries" do
      let(:sql) { [] }
      let(:queries_from) { ->(table) { sql.count { |query| query.include?(%(FROM "#{table}")) } } }

      let_it_be(:photo_articles) do
        (1..3).map do |i|
          author = create(:user, player: create(:player, name: "Writer #{i}"))
          create(:news, :published, :with_photo, title: "Photo #{i}", author: author,
                                                 published_at: Time.zone.local(2026, 5, i))
        end
      end

      before do
        ActiveSupport::Notifications.subscribed(->(*, payload) { sql << payload[:sql] }, "sql.active_record") do
          get root_path
        end
      end

      it { expect(news_column.css("article img").size).to eq(3) }
      it { expect(queries_from.call("action_text_rich_texts")).to eq(1) }
      # One for the photos, one for the blobs' preview images: three articles, so a query per article would show.
      it { expect(queries_from.call("active_storage_attachments")).to eq(2) }
      it { expect(queries_from.call("active_storage_blobs")).to eq(1) }
      it { expect(queries_from.call("users")).to eq(1) }
      it { expect(sql.grep(/FROM "players" WHERE "players"."id" = /)).to be_empty }
      it { expect(sql.grep(/FROM "competitions" WHERE "competitions"."id" = /)).to be_empty }
      it { expect(sql.grep(/SELECT 1 AS one/)).to be_empty }
    end

    describe "release notes" do
      let_it_be(:user) { create(:user) }
      let_it_be(:announcement) { create(:announcement, message_ru: "Заметка о выпуске", message_en: "Release note") }

      before do
        toggles.each { |key| create(:feature_toggle, key: key, enabled: true) }
        sign_in user
        get root_path
      end

      context "when only home_whats_new is enabled" do
        let(:toggles) { %w[home_whats_new] }

        it { expect(controller.instance_variable_get(:@announcements)).to be_nil }
        it { expect(response.body).not_to include("Заметка о выпуске") }
      end

      context "when toast_whats_new is enabled" do
        let(:toggles) { %w[toast_whats_new] }

        it { expect(controller.instance_variable_get(:@announcements)).to include(announcement) }
        it { expect(response.body).to include("Заметка о выпуске") }
      end
    end

    describe "block toggles" do
      before do
        toggles.each { |key| create(:feature_toggle, key: key, enabled: false) }
        get root_path
      end

      context "when home_running_tournaments is disabled" do
        let(:toggles) { %w[home_running_tournaments] }

        it { expect(running).to be_nil }
        it { expect(controller.instance_variable_get(:@mini_standings)).to be_nil }
        it { expect(recently_finished).to be_present }
      end

      context "when home_recently_finished is disabled" do
        let(:toggles) { %w[home_recently_finished] }

        it { expect(recently_finished).to be_nil }
        it { expect(controller.instance_variable_get(:@winners)).to be_nil }
        it { expect(recent_games).to be_present }
      end

      context "when home_recent_games is disabled" do
        let(:toggles) { %w[home_recent_games] }

        it { expect(recent_games).to be_nil }
        it { expect(controller.instance_variable_get(:@recent_games)).to be_nil }
        it { expect(running).to be_present }
      end

      context "when home_latest_news is disabled" do
        let(:toggles) { %w[home_latest_news] }

        it { expect(news_column).to be_nil }
        it { expect(controller.instance_variable_get(:@latest_news)).to be_nil }
        it { expect(columns["class"].split).not_to include(two_columns_class) }
      end

      context "when every results block is disabled" do
        let(:toggles) { %w[home_running_tournaments home_recently_finished home_recent_games] }

        it { expect(results).to be_nil }
        it { expect(news_column).to be_present }
        it { expect(columns["class"].split).not_to include(two_columns_class) }
      end

      context "when every block is disabled" do
        let(:toggles) { %w[home_running_tournaments home_recently_finished home_recent_games home_latest_news] }

        it { expect(columns).to be_nil }
      end
    end
  end

  context "with nothing to show" do
    before { get root_path }

    it { expect(response).to have_http_status(:ok) }
    it { expect(columns).to be_nil }
    it { expect(main.at_css("h1.sr-only").text).to eq(I18n.t("home.hero.title")) }
  end

  context "with only news" do
    let_it_be(:article) { create(:news, :published, title: "Lonely News") }

    before { get root_path }

    it { expect(results).to be_nil }
    it { expect(news_column.text).to include("Lonely News") }
    it { expect(columns["class"].split).not_to include(two_columns_class) }
  end

  context "with no news" do
    let_it_be(:game) { create(:game, played_on: Date.new(2026, 3, 1), result: "draw") }

    before { get root_path }

    it { expect(news_column).to be_nil }
    it { expect(recent_games.at_css(".vm-pill--neutral")).to be_present }
    it { expect(columns["class"].split).not_to include(two_columns_class) }
  end
end
