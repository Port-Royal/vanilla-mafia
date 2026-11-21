require "rails_helper"

RSpec.describe "Redesigned competition page" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:header) { document.at_css("#competition-header") }
  let(:crumbs) { header.at_css("nav[aria-label='Breadcrumb']") }
  let(:meta) { document.at_css("#competition-meta") }
  let(:running_pill) { meta.at_css(".vm-pill.vm-pill--neutral") }
  let(:sections) { document.css("main section[id^='competition-']").map { |section| section["id"] } }
  let(:rating) { document.at_css("#competition-rating") }
  let(:rating_row) { ->(name) { rating.css("tbody tr").find { |tr| tr.at_css("a").text == name } } }
  let(:children) { document.at_css("#competition-children") }
  let(:child_row) { ->(child) { children.at_css("tr[data-competition='#{child.slug}']") } }
  let(:chip) { ->(child, game) { child_row.(child).at_css("a[href='#{game_path(game)}']") } }
  let(:matrix) { document.at_css("#competition-matrix") }
  let(:matrix_row) { ->(player) { matrix.at_css("tbody tr[data-player='#{player.id}']") } }
  let(:matrix_cell) { ->(player, game) { matrix_row.(player).at_css("td[data-game='#{game.id}']") } }
  let(:news) { document.at_css("#competition-news") }

  let_it_be(:role) { create(:role) }
  let_it_be(:season) { create(:competition, :season, name: "Season 6", started_on: Date.new(2026, 9, 1)) }
  let_it_be(:finished_series) do
    create(:competition, :series, parent: season, name: "Series 1", position: 1,
                                  started_on: Date.new(2026, 9, 1), ended_on: Date.new(2026, 9, 30))
  end
  let_it_be(:running_series) do
    create(:competition, :series, parent: season, name: "Series 2", position: 2, started_on: Date.new(2026, 10, 1))
  end
  let_it_be(:empty_series) { create(:competition, :series, parent: season, name: "Series 3", position: 3) }
  let_it_be(:first_game) { create(:game, competition: finished_series, game_number: 1, result: "peace_victory") }
  let_it_be(:second_game) { create(:game, competition: finished_series, game_number: 2, result: "mafia_victory") }
  let_it_be(:live_game) { create(:game, competition: running_series, game_number: 3, result: "in_progress") }
  let_it_be(:baron) { create(:player, name: "Baron") }
  let_it_be(:laska) { create(:player, name: "Laska") }
  let_it_be(:graf) { create(:player, name: "Graf") }
  let_it_be(:kira) { create(:player, name: "Kira") }

  before_all do
    create(:game_participation, game: first_game, player: baron, role:, plus: 3, win: true)
    create(:game_participation, game: first_game, player: laska, role:, plus: 1)
    create(:game_participation, game: first_game, player: kira, role:, minus: 1.25)
    create(:game_participation, game: first_game, player: graf, role:, plus: 0.5, win: true)
    create(:game_participation, game: second_game, player: baron, role:, plus: 1, win: true)
    create(:game_participation, game: second_game, player: laska, role:, plus: 2, win: true)
    create(:game_participation, game: second_game, player: graf, role:, plus: 0.5)
    create(:game_participation, game: live_game, player: laska, role:, plus: 1)
  end

  context "with the default design" do
    before { get competition_path(slug: season.slug) }

    it { expect(document.at_css("table.data-table")).to be_present }
    it { expect(header).to be_nil }
  end

  context "with the new design" do
    include_context "with the new design"

    describe "a parent competition (season)" do
      before { get competition_path(slug: season.slug) }

      describe "header" do
        it { expect(crumbs).to be_nil }
        it { expect(header.at_css("h1.font-serif").text.strip).to eq("Season 6") }
        it { expect(running_pill.text.strip).to eq(I18n.t("competitions.redesign.running")) }
        it { expect(meta.text).to include("с 01.09.2026") }
        it { expect(meta.text.squish).to include("3 серии · 3 игры · 4 игрока") }
      end

      it { expect(sections).to eq(%w[competition-rating competition-children]) }

      describe "rating" do
        let(:medal) { ->(name) { rating_row.(name).at_css(".vm-medal") } }
        let(:fold_line) { rating_row.("Baron").at_css(".vm-sub") }

        it { expect(rating.at_css(".vm-label").text).to eq(I18n.t("competitions.redesign.rating")) }
        it { expect(rating.css("tbody tr a").map(&:text)).to eq(%w[Baron Laska Graf Kira]) }
        it { expect(rating_row.("Baron").at_css("a")["href"]).to eq(player_path(baron)) }
        it { expect(medal.("Baron")["class"].split).to include("vm-medal--1") }
        it { expect(medal.("Laska")["class"].split).to include("vm-medal--2") }
        it { expect(medal.("Graf")["class"].split).to include("vm-medal--3") }
        it { expect(medal.("Kira")["class"].split).not_to include("vm-medal--1", "vm-medal--2", "vm-medal--3") }
        it { expect(medal.("Kira").text).to eq("4") }
        it { expect(rating_row.("Baron").at_css("td[data-column='rating']").text.strip).to eq("4") }
        it { expect(rating_row.("Kira").at_css("td[data-column='rating']").text.strip).to eq("−1.25") }
        it { expect(rating_row.("Baron").at_css("td[data-column='games']").text.strip).to eq("2") }
        it { expect(rating_row.("Graf").at_css("td[data-column='win_rate']").text.strip).to eq("50.0%") }
        it { expect(rating_row.("Baron").at_css("td[data-column='games']")["class"].split).to include("hidden", "lg:table-cell") }
        it { expect(fold_line["class"].split).to include("lg:hidden") }
        it { expect(fold_line.text.squish).to eq("2 игры · 100.0%") }
      end

      describe "children" do
        it { expect(children.at_css(".vm-label").text).to eq("Серии") }

        it "lists children in order" do
          expect(children.css("tbody tr").map { |tr| tr["data-competition"] })
            .to eq([ finished_series.slug, running_series.slug, empty_series.slug ])
        end

        it { expect(child_row.(finished_series).at_css("a[href='#{competition_path(slug: finished_series.slug)}']").text).to eq("Series 1") }
        it { expect(child_row.(finished_series).at_css(".vm-sub").text.squish).to eq("01.09.2026 – 30.09.2026 · победитель Baron") }
        it { expect(child_row.(finished_series).at_css(".vm-sub a")["href"]).to eq(player_path(baron)) }
        it { expect(child_row.(running_series).at_css(".vm-sub").text.squish).to eq("идёт") }
        it { expect(chip.(finished_series, first_game).text).to eq("1") }
        it { expect(chip.(finished_series, second_game).text).to eq("2") }
        it { expect(chip.(finished_series, first_game)["class"].split).not_to include("border-gold") }
        it { expect(chip.(running_series, live_game)["class"].split).to include("border-gold") }

        context "with a running child that has no games and no players" do
          it { expect(child_row.(empty_series).at_css(".vm-sub").text.squish).to eq("идёт") }
          it { expect(child_row.(empty_series).css("a").size).to eq(1) }
        end
      end

      context "with news" do
        let_it_be(:article) { create(:news, :published, title: "Season recap", competition: season) }

        it { expect(sections).to eq(%w[competition-rating competition-children competition-news]) }
        it { expect(news.at_css(".vm-label").text).to eq(I18n.t("competitions.redesign.news")) }
        it { expect(news.at_css("h3 > a[href='#{news_path(article)}']").text).to eq("Season recap") }
        it { expect(news.at_css("a[href='#{news_index_path}']")).to be_nil }
      end
    end

    describe "a finished parent" do
      let_it_be(:old_season) do
        create(:competition, :season, name: "Season 5", started_on: Date.new(2025, 9, 1), ended_on: Date.new(2026, 5, 31))
      end
      let_it_be(:old_series) { create(:competition, :series, parent: old_season) }

      before { get competition_path(slug: old_season.slug) }

      it { expect(running_pill).to be_nil }
      it { expect(meta.text).to include("01.09.2025 – 31.05.2026") }
      it { expect(meta.text.squish).to include("1 серия · 0 игр · 0 игроков") }
      it { expect(sections).to eq(%w[competition-children]) }
    end

    describe "a tournament parent" do
      let_it_be(:tournament) { create(:competition, :tournament, name: "Cup") }
      let_it_be(:stages) { (1..2).map { |i| create(:competition, :round, parent: tournament, name: "Round #{i}") } }
      let_it_be(:stage_game) { create(:game, competition: stages.first, game_number: 1, result: "draw") }
      let_it_be(:group) { create(:competition, :group, parent: stages.first, name: "Group A") }
      let_it_be(:group_game) { create(:game, competition: group, game_number: 2, result: "draw") }

      before_all { create(:game_participation, game: stage_game, player: baron, role:, plus: 1) }

      before { get competition_path(slug: tournament.slug) }

      it { expect(children.at_css(".vm-label").text).to eq("Этапы") }
      it { expect(meta.text.squish).to include("2 этапа · 2 игры · 1 игрок") }
      it { expect(children.at_css("a[href='#{game_path(group_game)}']")).to be_nil }
      it { expect(document.at_css("main").text).not_to include("Серии") }
      it { expect(document.at_css("main").text).not_to include("серий") }
    end

    describe "a leaf competition" do
      let(:column_headers) { matrix.css("thead th") }

      before { get competition_path(slug: finished_series.slug) }

      describe "header" do
        it { expect(crumbs.css("a").map { |a| a["href"] }).to eq([ competition_path(slug: season.slug) ]) }
        it { expect(crumbs.text).to include("Series 1") }
        it { expect(header.at_css("h1").text.strip).to eq("Series 1") }
        it { expect(running_pill).to be_nil }
        it { expect(meta.text).to include("01.09.2026 – 30.09.2026") }
        it { expect(meta.text.squish).to include("2 игры · 4 игрока") }
        it { expect(meta.text).not_to include("сери") }
      end

      describe "matrix" do
        let(:total_cells) { matrix_row.(baron).css("td[data-column='total']") }

        it { expect(sections).to eq(%w[competition-matrix]) }
        it { expect(matrix.css("tbody tr").map { |tr| tr["data-player"] }).to eq([ baron, laska, graf, kira ].map { |p| p.id.to_s }) }
        it { expect(matrix_row.(baron).at_css("td.sticky .vm-medal--1").text).to eq("1") }
        it { expect(matrix_row.(kira).at_css("td.sticky .vm-medal").text).to eq("4") }
        it { expect(matrix_row.(kira).at_css("td.sticky a")["href"]).to eq(player_path(kira)) }
        it { expect(matrix.at_css("thead a[href='#{game_path(first_game)}']").text).to eq("И1") }
        it { expect(matrix.at_css("thead a[href='#{game_path(second_game)}']").text).to eq("И2") }
        it { expect(matrix_cell.(baron, first_game).text.strip).to eq("3") }
        it { expect(matrix_cell.(graf, first_game).text.strip).to eq("0.5") }
        it { expect(matrix_cell.(baron, first_game)["class"].split).to include("bg-gold-wash") }
        it { expect(matrix_cell.(laska, first_game)["class"].split).not_to include("bg-gold-wash") }
        it { expect(matrix_cell.(kira, first_game).text.strip).to eq("−1.25") }
        it { expect(matrix_cell.(kira, first_game)["class"].split).to include("text-alert-ink") }
        it { expect(matrix_cell.(baron, first_game)["class"].split).not_to include("text-alert-ink") }
        it { expect(total_cells.map { |td| td.text.strip }).to eq(%w[4 4]) }
        it { expect(total_cells.first["class"].split).to include("lg:hidden") }
        it { expect(total_cells.last["class"].split).to include("hidden", "lg:table-cell") }
        it { expect(matrix_row.(baron).css("td").last).to eq(total_cells.last) }
        it { expect(matrix_row.(baron).css("td")[1]).to eq(total_cells.first) }
        it { expect(column_headers.map { |th| th.text.strip }.count(I18n.t("competitions.show.total"))).to eq(2) }
        it { expect(document.at_css("#competition-legend").text).to eq(I18n.t("competitions.redesign.legend")) }

        context "with a player who skipped a game" do
          it { expect(matrix_cell.(kira, second_game).text.strip).to be_empty }
          it { expect(matrix_row.(kira).at_css("td[data-column='total']").text.strip).to eq("−1.25") }
        end
      end
    end

    describe "a running leaf without games" do
      before { get competition_path(slug: empty_series.slug) }

      it { expect(running_pill).to be_present }
      it { expect(meta.text.squish).to include("0 игр · 0 игроков") }
      it { expect(matrix).to be_nil }
      it { expect(document.at_css("main").text).to include(I18n.t("competitions.redesign.no_games")) }
      it { expect(document.at_css("#competition-legend")).to be_nil }
    end
  end
end
