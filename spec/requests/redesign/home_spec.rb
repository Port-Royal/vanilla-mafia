require "rails_helper"

RSpec.describe "Redesigned home page" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:main) { document.at_css("main#site-main") }
  let(:columns) { document.at_css("#home-columns") }
  let(:results) { document.at_css("#home-results") }
  let(:news_column) { document.at_css("#home-news") }
  let(:running) { document.at_css("#home-running") }
  let(:recently_finished) { document.at_css("#home-recently-finished") }
  let(:recent_games) { document.at_css("#home-recent-games") }
  let(:two_columns_class) { "lg:grid-cols-[11fr_9fr]" }

  context "with the default design" do
    before { get root_path }

    it { expect(document.at_css("body").text).to include(I18n.t("home.hero.tagline")) }
    it { expect(results).to be_nil }
  end

  context "with the new design" do
    include_context "with the new design"

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

    describe "removed blocks" do
      before { get root_path }

      it { expect(main.text).not_to include(I18n.t("home.hero.title")) }
      it { expect(main.text).not_to include(I18n.t("home.hero.tagline")) }
      it { expect(main.text).not_to include(I18n.t("home.whats_new.title")) }
      it { expect(main.text).not_to include(I18n.t("home.hall_of_fame.title")) }
      it { expect(main.text).not_to include(I18n.t("home.stats.title")) }
      it { expect(main.text).not_to include(I18n.t("home.documents.title")) }
      it { expect(controller.instance_variable_get(:@stats)).to be_nil }
      it { expect(controller.instance_variable_get(:@hall_of_fame_players)).to be_nil }
    end

    describe "columns" do
      before { get root_path }

      it { expect(columns["class"].split).to include("grid", two_columns_class) }
      it { expect(columns.element_children.map { |child| child["id"] }).to eq(%w[home-results home-news]) }
    end

    describe "running now" do
      let(:panel) { running.at_css(".vm-panel") }
      let(:rows) { panel.css("tbody tr") }

      before { get root_path }

      it { expect(running.at_css(".vm-label").text).to eq(I18n.t("home.redesign.running")) }
      it { expect(panel.at_css("a[href='#{competition_path(slug: season.slug)}']").text.strip).to eq("Season 6") }
      it { expect(panel.css("a[href='#{competition_path(slug: season.slug)}']").map(&:text).join).to include(I18n.t("home.redesign.table_link")) }
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

      it { expect(recent_games.at_css(".vm-label").text).to eq(I18n.t("home.redesign.recent_games")) }
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

      before { get root_path }

      it { expect(news_column.at_css(".vm-label").text).to eq(I18n.t("home.redesign.news")) }
      it { expect(news_column.at_css("a[href='#{news_index_path}']").text).to include(I18n.t("home.redesign.all_news")) }
      it { expect(item.at_css("a[href='#{news_path(article)}']").text).to eq("Big Recap") }
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

      context "when the old page's own blocks are disabled" do
        let(:toggles) { %w[home_hero home_hall_of_fame home_stats home_whats_new home_documents] }

        it { expect(columns["class"].split).to include(two_columns_class) }
        it { expect([ running, recently_finished, recent_games, news_column ]).to all(be_present) }
      end
    end
  end

  context "with the new design and nothing to show" do
    include_context "with the new design"

    before { get root_path }

    it { expect(response).to have_http_status(:ok) }
    it { expect(columns).to be_nil }
  end

  context "with the new design and only news" do
    include_context "with the new design"

    let_it_be(:article) { create(:news, :published, title: "Lonely News") }

    before { get root_path }

    it { expect(results).to be_nil }
    it { expect(news_column.text).to include("Lonely News") }
    it { expect(columns["class"].split).not_to include(two_columns_class) }
  end

  context "with the new design and no news" do
    include_context "with the new design"

    let_it_be(:game) { create(:game, played_on: Date.new(2026, 3, 1), result: "draw") }

    before { get root_path }

    it { expect(news_column).to be_nil }
    it { expect(recent_games.at_css(".vm-pill--neutral")).to be_present }
    it { expect(columns["class"].split).not_to include(two_columns_class) }
  end
end
