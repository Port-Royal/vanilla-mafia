require "rails_helper"

RSpec.describe GamesController do
  describe "GET /games/:slug" do
    let_it_be(:season) { create(:competition, :season, name: "Сезон 1") }
    let_it_be(:series) { create(:competition, :series, name: "Серия 1", parent: season) }
    let_it_be(:game) { create(:game, competition: series, game_number: 1) }

    context "when game is a draw" do
      let_it_be(:draw_game) { create(:game, competition: series, game_number: 2, result: "draw") }

      before { get game_path(draw_game) }

      it "renders the draw label" do
        assert_select "#game-meta .vm-pill", text: I18n.t("games.show.result.draw")
      end
    end

    context "when game exists" do
      let_it_be(:role) { create(:role, code: "peace", name: "Мирный") }
      let_it_be(:participation) { create(:game_participation, game: game, role_code: "peace", plus: 2.0, minus: 0.5, seat: 3) }

      before { get game_path(game) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders breadcrumb with link to root competition" do
        assert_select "nav[aria-label='Breadcrumb'] a[href=?]", competition_path(slug: season.slug), text: season.name
      end

      it "renders breadcrumb with link to parent competition" do
        assert_select "nav[aria-label='Breadcrumb'] a[href=?]", competition_path(slug: series.slug), text: series.name
      end

      it "renders breadcrumb with game name as text" do
        assert_select "nav[aria-label='Breadcrumb'] span", text: /#{I18n.t('common.game')} #{game.game_number}/
      end

      it "renders player name as link to profile" do
        assert_select "td a[href=?]", player_path(participation.player), text: participation.player.name
      end

      it "renders role icon" do
        assert_select "td img[src*='roles/peace'][alt='Мирный']"
      end

      it "renders seat number in table cell" do
        assert_select "tbody td", text: "3"
      end

      it "shows edit protocol link for users with protocol access" do
        admin = create(:user, :admin)
        sign_in admin
        get game_path(game)
        expect(response.body).to include(edit_judge_protocol_path(game))
      end

      it "does not show edit protocol link for regular users" do
        user = create(:user)
        sign_in user
        get game_path(game)
        expect(response.body).not_to include(edit_judge_protocol_path(game))
      end
    end

    context "when game does not exist" do
      before { get game_path(slug: "nonexistent-slug") }

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

RSpec.describe "Game page" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:header) { document.at_css("#game-header") }
  let(:crumbs) { header.at_css("nav[aria-label='Breadcrumb']") }
  let(:meta) { document.at_css("#game-meta") }
  let(:table) { document.at_css("#game-table") }
  let(:column_headers) { table.css("thead th").map { |th| th.text.strip } }
  let(:rows) { table.css("tbody tr") }
  let(:row) { ->(seat) { table.at_css("tbody tr[data-seat='#{seat}']") } }
  let(:cell) { ->(seat, column) { row.(seat).at_css("td[data-column='#{column}']") } }
  let(:details) { ->(seat) { row.(seat).at_css("[data-part='details']") } }
  let(:score_parts_line) { ->(seat) { row.(seat).at_css("[data-part='score-parts']") } }
  let(:legend) { document.at_css("#game-legend") }
  let(:neighbours) { document.at_css("nav#game-neighbours") }
  let(:winner_mark) { ->(seat) { cell.(seat, "player").at_css("[data-part='winner']") } }

  let_it_be(:season) { create(:competition, :season, name: "Season 6") }
  let_it_be(:series) { create(:competition, :series, parent: season, name: "Series 3") }
  let_it_be(:peace) { create(:role, code: "peace", name: "Мирный") }
  let_it_be(:mafia) { create(:role, code: "mafia", name: "Мафия") }
  let_it_be(:game) do
    create(:game, competition: series, game_number: 14, played_on: Date.new(2026, 3, 20), judge: "Judge Judy",
                  table_number: 2, result: "peace_victory")
  end
  let_it_be(:baron) do
    create(:game_participation, game:, seat: 1, role: peace, win: true, plus: 1, minus: 0, best_move: 0.4,
                                first_shoot: true, status: :killed_by_mafia, best_move_seats: [ 2, 5, 7 ],
                                player: create(:player, name: "Baron"))
  end
  let_it_be(:laska) do
    create(:game_participation, game:, seat: 2, role: mafia, plus: 0, minus: 0.2, status: :voted_out,
                                player: create(:player, name: "Laska"))
  end
  let_it_be(:shadow) do
    create(:game_participation, game:, seat: 3, role: mafia, plus: 0, minus: 1, status: :banned,
                                player: create(:player, name: "Shadow"))
  end
  let_it_be(:kira) do
    create(:game_participation, game:, seat: 4, role: peace, win: true, plus: 1, best_move: nil,
                                best_move_seats: [ 3 ], player: create(:player, name: "Kira"))
  end


  describe "header" do
    before { get game_path(game) }

    it { expect(crumbs.at_css("a[href='#{competition_path(slug: season.slug)}']").text).to eq("Season 6") }
    it { expect(crumbs.at_css("a[href='#{competition_path(slug: series.slug)}']").text).to eq("Series 3") }
    it { expect(crumbs.css("a").size).to eq(2) }
    it { expect(crumbs.text).to include("#{I18n.t('common.game')} 14") }
    it { expect(header.at_css("h1").text.strip).to eq("#{I18n.t('common.game')} 14") }
    it { expect(meta.at_css(".vm-pill.vm-pill--gold").text).to eq(I18n.t("activerecord.attributes.game.results.peace_victory")) }
    it { expect(meta.text).to include("20.03.2026") }
    it { expect(meta.text).to include(I18n.t("games.show.judge", name: "Judge Judy")) }
    it { expect(meta.text).to include(I18n.t("games.show.table_number", number: 2)) }
    it { expect(header.text).not_to include(I18n.t("game_protocols.edit_link")) }
  end

  describe "a named game" do
    let_it_be(:named) { create(:game, competition: series, game_number: 20, name: "Final") }

    before { get game_path(named) }

    it { expect(header.at_css("h1").text.squish).to eq("#{I18n.t('common.game')} 20 Final") }
  end

  describe "a game with no date, judge or table" do
    let_it_be(:bare) { create(:game, competition: series, game_number: 30, result: "mafia_victory") }

    before { get game_path(bare) }

    it { expect(meta.element_children.size).to eq(1) }
    it { expect(meta.at_css(".vm-pill.vm-pill--alert")).to be_present }
    it { expect(meta.text.strip).to eq(I18n.t("activerecord.attributes.game.results.mafia_victory")) }
  end

  describe "the edit link" do
    before do
      sign_in user
      get game_path(game)
    end

    context "with a protocol manager" do
      let(:user) { create(:user, :admin) }

      it { expect(header.at_css("a[href='#{edit_judge_protocol_path(game)}']").text).to eq(I18n.t("game_protocols.edit_link")) }
    end

    context "with a regular user" do
      let(:user) { create(:user) }

      it { expect(header.at_css("a[href='#{edit_judge_protocol_path(game)}']")).to be_nil }
    end
  end

  describe "a finished game" do
    before { get game_path(game) }

    it "has the score columns" do
      expect(column_headers).to eq([ I18n.t("games.show.seat"), I18n.t("games.show.player"),
                                     I18n.t("games.show.base_score"),
                                     I18n.t("activerecord.attributes.game_participation.minus"),
                                     I18n.t("games.redesign.best_move_short"), I18n.t("games.show.total") ])
    end

    it { expect(rows.map { |tr| tr["data-seat"] }).to eq(%w[1 2 3 4]) }
    it { expect(cell.(1, "player").at_css("a[href='#{player_path(baron.player)}']").text).to eq("Baron") }
    it { expect(cell.(1, "player").at_css("img[src*='roles/peace'][alt='Мирный']")).to be_present }
    it { expect(cell.(2, "player").at_css("img[src*='roles/mafia'][alt='Мафия']")).to be_present }
    it { expect(cell.(1, "plus").text.strip).to eq("1") }
    it { expect(cell.(1, "best_move").text.strip).to eq("0.4") }
    it { expect(cell.(1, "total").text.strip).to eq("1.4") }
    it { expect(cell.(2, "minus").text.strip).to eq("−0.2") }
    it { expect(cell.(2, "minus")["class"]).to include("text-alert-ink") }
    it { expect(cell.(2, "total").text.strip).to eq("−0.2") }
    it { expect(cell.(3, "minus").text.strip).to eq("−1") }
    it { expect(cell.(1, "minus").text.strip).to be_empty }
    it { expect(cell.(1, "minus")["class"]).not_to include("text-alert-ink") }
    it { expect(cell.(2, "best_move").text.strip).to be_empty }
    it { expect(cell.(2, "plus").text.strip).to eq("0") }
    it { expect(cell.(1, "plus")["class"]).to include("hidden", "lg:table-cell") }
    it { expect(cell.(1, "total")["class"]).not_to include("hidden") }
    it { expect(row.(1)["class"]).to include("vm-row--highlight") }
    it { expect(row.(4)["class"]).to include("vm-row--highlight") }
    it { expect(row.(2)["class"].to_s).not_to include("vm-row--highlight") }
    it { expect(winner_mark.(1).text).to eq(I18n.t("games.redesign.winner")) }
    it { expect(winner_mark.(1)["class"]).to include("sr-only") }
    it { expect(winner_mark.(4).text).to eq(I18n.t("games.redesign.winner")) }
    it { expect(winner_mark.(2)).to be_nil }
    it { expect(legend.text.strip).to eq(I18n.t("games.redesign.legend")) }
    it { expect(table.at_css("thead abbr[title='#{I18n.t('games.redesign.best_move_full')}']").text).to eq(I18n.t("games.redesign.best_move_short")) }
  end

  describe "a finished game in English" do
    before do
      cookies[:locale] = "en"
      get game_path(game)
    end

    it { expect(column_headers).to eq(%w[Seat Player Score Minus BM Total]) }
    it { expect(document.at_css(".translation_missing")).to be_nil }
    it { expect(winner_mark.(1).text).to eq("winner") }
    it { expect(details.(1).at_css("abbr[title='first killed']").text).to eq("FK") }
    it { expect(details.(1).at_css("abbr[title='best move']").text).to eq("BM") }
    it { expect(neighbours["aria-label"]).to eq("Game navigation") }
  end

  describe "a finished game with hidden roles" do
    let_it_be(:hidden_series) { create(:competition, :series, parent: season, name: "Series 5") }
    let_it_be(:hidden) { create(:game, competition: hidden_series, game_number: 1, hide_roles: true, result: "mafia_victory") }
    let_it_be(:hidden_seat) { create(:game_participation, game: hidden, seat: 1, role: mafia) }

    before { get game_path(hidden) }

    it { expect(table.at_css("img[src*='roles/mafia']")).to be_present }
  end

  describe "the secondary line" do
    before { get game_path(game) }

    it { expect(details.(1).at_css("[data-part='first-shoot']").text).to eq(I18n.t("games.redesign.first_shoot")) }
    it { expect(details.(1).at_css("[data-part='first-shoot'] abbr")["title"]).to eq(I18n.t("games.redesign.first_shoot_full")) }
    it { expect(details.(1).at_css("abbr[title='#{I18n.t('games.redesign.best_move_full')}']").text).to eq(I18n.t("games.redesign.best_move_short")) }
    it { expect(details.(2).at_css("[data-part='first-shoot']")).to be_nil }
    it { expect(details.(1).text).to include(I18n.t("games.overlay.status.killed_by_mafia")) }
    it { expect(details.(2).text).to include(I18n.t("games.overlay.status.voted_out")) }
    it { expect(details.(3).text).to include(I18n.t("games.overlay.status.banned")) }
    it { expect(details.(4).text).not_to include(I18n.t("games.overlay.status.alive")) }
    it { expect(details.(1).text).to include("#{I18n.t('games.redesign.best_move_short')}: 2, 5, 7") }
    it { expect(details.(4).text).to include("#{I18n.t('games.redesign.best_move_short')}: 3") }
    it { expect(details.(2).text).not_to include(I18n.t("games.redesign.best_move_short")) }
    it { expect(score_parts_line.(1).text.strip).to eq("· 1 + #{I18n.t('games.redesign.best_move_short')} 0.4") }
    it { expect(score_parts_line.(1)["class"]).to include("lg:hidden") }
    it { expect(score_parts_line.(4).text.strip).to eq("· 1") }
  end

  describe "a player with no details" do
    let_it_be(:quiet_game) { create(:game, competition: series, game_number: 40, result: "draw") }
    let_it_be(:quiet) { create(:game_participation, game: quiet_game, seat: 5, role: nil, plus: 0.5, minus: 0) }

    before { get game_path(quiet_game) }

    it { expect(details.(5)["class"]).to include("lg:hidden") }
    it { expect(score_parts_line.(5).text.strip).to eq("0.5") }
    it { expect(meta.at_css(".vm-pill.vm-pill--neutral")).to be_present }
    it { expect(row.(5)["class"].to_s).not_to include("vm-row--highlight") }
  end

  describe "a first-killed player still alive with no best move seats" do
    let_it_be(:odd_game) { create(:game, competition: series, game_number: 45, result: "draw") }
    let_it_be(:odd) { create(:game_participation, game: odd_game, seat: 6, role: nil, plus: 1, best_move: 0.4, first_shoot: true) }

    before { get game_path(odd_game) }

    it { expect(details.(6).text.squish).to eq("#{I18n.t('games.redesign.first_shoot')} · 1 + #{I18n.t('games.redesign.best_move_short')} 0.4") }
    it { expect(score_parts_line.(6).text.strip).to eq("· 1 + #{I18n.t('games.redesign.best_move_short')} 0.4") }
  end

  describe "row order" do
    let_it_be(:ordered_game) { create(:game, competition: series, game_number: 60, result: "draw") }
    let_it_be(:names) { %w[Unseated-A Seat-Two Unseated-B Seat-One] }

    before_all do
      [ nil, 2, nil, 1 ].zip(names).each do |seat, name|
        create(:game_participation, game: ordered_game, seat:, role: nil, player: create(:player, name:))
      end
    end

    before { get game_path(ordered_game) }

    it "lists seats first, then the unseated in the order they were added" do
      expect(rows.map { |tr| tr.at_css("td[data-column='player'] a").text }).to eq(%w[Seat-One Seat-Two Unseated-A Unseated-B])
    end
  end

  describe "loading the rows" do
    let_it_be(:don) { create(:role, code: "don", name: "Дон") }
    let_it_be(:sheriff) { create(:role, code: "sheriff", name: "Шериф") }
    let_it_be(:one_row) { create(:game, competition: series, game_number: 70, result: "draw") }
    let_it_be(:three_rows) { create(:game, competition: series, game_number: 71, result: "draw") }
    let(:queries_for) do
      lambda do |shown|
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get game_path(shown) }
        count
      end
    end

    # Each row has its own player and role, so a lazy load per row would be a fresh query, never a cache hit.
    before_all do
      create(:game_participation, game: one_row, seat: 1, role: peace)
      [ mafia, don, sheriff ].each.with_index(1) { |role, seat| create(:game_participation, game: three_rows, seat:, role:) }
    end

    it "loads players and roles for all rows at once" do
      expect(queries_for.(three_rows)).to eq(queries_for.(one_row))
    end
  end

  describe "a game in progress" do
    let_it_be(:live_series) { create(:competition, :series, parent: season, name: "Series 4") }
    let_it_be(:live) { create(:game, competition: live_series, game_number: 3, hide_roles: true) }
    let_it_be(:killed) do
      create(:game_participation, game: live, seat: 1, role: peace, plus: 1, best_move: 0.4, first_shoot: true,
                                  status: :killed_by_mafia, best_move_seats: [ 4 ])
    end

    before { get game_path(live) }

    it { expect(meta.at_css(".vm-pill.vm-pill--neutral").text.strip).to eq(I18n.t("games.show.result.in_progress")) }
    it { expect(column_headers).to eq([ I18n.t("games.show.seat"), I18n.t("games.show.player") ]) }
    it { expect(row.(1).css("td").size).to eq(2) }
    it { expect(score_parts_line.(1)).to be_nil }
    it { expect(legend).to be_nil }
    it { expect(details.(1).text).to include(I18n.t("games.overlay.status.killed_by_mafia")) }
    it { expect(details.(1).text).to include("#{I18n.t('games.redesign.best_move_short')}: 4") }
    it { expect(details.(1).at_css("[data-part='first-shoot']")).to be_present }
    it { expect(details.(1).at_css("abbr[title='#{I18n.t('games.redesign.first_shoot_full')}']")).to be_present }
    it { expect(details.(1).at_css("abbr[title='#{I18n.t('games.redesign.best_move_full')}']")).to be_present }
    it { expect(details.(1)["class"]).not_to include("lg:hidden") }
    it { expect(table.css("img[src*='roles/']")).to be_empty }
    it { expect(neighbours.css("a[href*='/games/']")).to be_empty }
    it { expect(neighbours.at_css("a[href='#{competition_path(slug: live_series.slug)}']")).to be_present }
  end

  describe "a game in progress with public roles" do
    let_it_be(:open_live) { create(:game, competition: series, game_number: 50) }
    let_it_be(:seated) { create(:game_participation, game: open_live, seat: 1, role: mafia) }

    before { get game_path(open_live) }

    it { expect(table.at_css("img[src*='roles/mafia']")).to be_present }
  end

  describe "neighbours" do
    let_it_be(:previous_game) { create(:game, competition: series, game_number: 13, played_on: game.played_on, table_number: 2) }
    let_it_be(:next_game) { create(:game, competition: series, game_number: 15, played_on: game.played_on, table_number: 2) }
    let(:links) { neighbours.css("a") }
    let(:sides) { neighbours.element_children }

    context "with a game in the middle" do
      before { get game_path(game) }

      it { expect(neighbours["aria-label"]).to eq(I18n.t("games.redesign.neighbours")) }
      it { expect(links.first["href"]).to eq(game_path(previous_game)) }
      it { expect(links.first.text.squish).to eq("← #{I18n.t('common.game')} 13") }
      it { expect(links.first.at_css("span[aria-hidden='true']").text).to eq("←") }
      it { expect(links.last["href"]).to eq(game_path(next_game)) }
      it { expect(links.last.text.squish).to eq("#{I18n.t('common.game')} 15 →") }
      it { expect(links.last.at_css("span[aria-hidden='true']").text).to eq("→") }

      it "links to the competition table in the middle" do
        expect(links[1]["href"]).to eq(competition_path(slug: series.slug))
      end

      it { expect(links[1].text.strip).to eq("Series 3: #{I18n.t('games.redesign.competition_table')}") }
    end

    context "with the first game" do
      before { get game_path(previous_game) }

      it { expect(sides.first.element_children).to be_empty }
      it { expect(links.size).to eq(2) }
      it { expect(links.last["href"]).to eq(game_path(game)) }
    end

    context "with the last game" do
      before { get game_path(next_game) }

      it { expect(sides.last.element_children).to be_empty }
      it { expect(links.size).to eq(2) }
      it { expect(links.first["href"]).to eq(game_path(game)) }
    end
  end

  describe "neighbours on other tables and days" do
    let_it_be(:tables_series) { create(:competition, :series, parent: season, name: "Series 7") }
    let_it_be(:first_table) { create(:game, competition: tables_series, game_number: 1, played_on: Date.new(2026, 3, 20), table_number: 1) }
    let_it_be(:second_table) { create(:game, competition: tables_series, game_number: 1, played_on: Date.new(2026, 3, 20), table_number: 2) }
    let_it_be(:next_day) { create(:game, competition: tables_series, game_number: 1, played_on: Date.new(2026, 3, 21), table_number: 1) }
    let(:links) { neighbours.css("a") }

    before { get game_path(second_table) }

    it { expect(links.first.text.squish).to eq("← #{I18n.t('common.game')} 1 · #{I18n.t('games.redesign.neighbour_table', number: 1)}") }

    it "names the table and the date of the next day's game" do
      expect(links.last.text.squish).to eq("#{I18n.t('common.game')} 1 · #{I18n.t('games.redesign.neighbour_table', number: 1)} · 21.03.2026 →")
    end
  end
end
