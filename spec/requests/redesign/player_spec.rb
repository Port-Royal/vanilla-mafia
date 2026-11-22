require "rails_helper"

RSpec.describe "Redesigned player profile" do
  include_context "with the new design"

  let(:document) { Nokogiri::HTML(response.body) }
  let(:header) { document.at_css("#player-header") }
  let(:number) { ->(key) { header.at_css("[data-number='#{key}']") } }
  let(:action) { document.at_css("#player-action") }
  let(:awards) { document.at_css("#player-awards") }
  let(:badges) { awards.css("[data-award]") }
  let(:roles) { document.at_css("#player-roles") }
  let(:section_labels) { document.css("main .vm-label").map { |label| label.text.strip } }

  let_it_be(:season) { create(:competition, :season, name: "Сезон 5", started_on: Date.new(2025, 11, 8)) }
  let_it_be(:series) { create(:competition, :series, parent: season, name: "Серия 1") }
  let_it_be(:peace) { create(:role, code: "peace", name: "Мирный") }
  let_it_be(:mafia) { create(:role, code: "mafia", name: "Мафия") }
  let_it_be(:player) { create(:player, name: "Финчер", bio: "Играю с первого сезона.\nЛюблю шерифа.") }
  let_it_be(:first_game) { create(:game, competition: series, played_on: Date.new(2025, 11, 8), result: "peace_victory") }
  let_it_be(:second_game) { create(:game, competition: series, played_on: Date.new(2025, 11, 15), result: "peace_victory") }

  before_all do
    create(:game_participation, game: first_game, player:, role: peace, win: true, plus: 1)
    create(:game_participation, game: second_game, player:, role: mafia, win: false)
  end

  describe "the page switch" do
    context "when the new design is off" do
      before do
        FeatureToggle.where(key: DesignPreference::TOGGLE_KEY).update_all(enabled: false)
        get player_path(player)
      end

      it "renders the old page" do
        expect(document.at_css("#player-header")).to be_nil
      end
    end
  end

  describe "header" do
    before { get player_path(player) }

    it "shows the name as the page title" do
      expect(header.at_css("h1").text.strip).to eq("Финчер")
    end

    it "shows the first letter when there is no photo" do
      expect(header.at_css("[data-part='initial']").text.strip).to eq("Ф")
    end

    it "hides the letter tile from screen readers" do
      expect(header.at_css("[data-part='initial']")["aria-hidden"]).to eq("true")
    end

    it "shows when the player started" do
      expect(header.at_css("#player-since").text.squish)
        .to eq("#{I18n.t('players.show.playing_since')} #{DatetimeFormatter.call(Date.new(2025, 11, 8), type: :date)}")
    end

    it "shows the games count with its word" do
      expect(number.("games").text.squish).to eq("2 #{I18n.t('players.redesign.numbers.games', count: 2)}")
    end

    it "shows the win rate" do
      expect(number.("win_rate").text.squish).to eq("50.0% #{I18n.t('players.redesign.numbers.wins_pct')}")
    end

    it "shows the competitions count" do
      expect(number.("competitions").text.squish).to eq("1 #{I18n.t('players.redesign.numbers.competitions', count: 1)}")
    end

    it "hides the awards number when there are none" do
      expect(number.("awards")).to be_nil
    end

    context "when the player has a photo" do
      before do
        player.photo.attach(io: Rails.root.join("spec/fixtures/files/selfie.jpg").open, filename: "selfie.jpg",
                            content_type: "image/jpeg")
        get player_path(player)
      end

      after { player.photo.purge }

      it "shows the photo with the name as alt text" do
        expect(header.at_css("img[data-part='photo']")["alt"]).to eq("Финчер")
      end

      it "drops the letter tile" do
        expect(header.at_css("[data-part='initial']")).to be_nil
      end
    end
  end

  describe "action" do
    let(:viewer) { create(:user) }

    context "when signed out" do
      before { get player_path(player) }

      it "shows no action" do
        expect(action).to be_nil
      end
    end

    context "when the viewer owns the profile" do
      before do
        viewer.update!(player:)
        sign_in viewer
        get player_path(player)
      end

      after { viewer.update!(player: nil) }

      it "links to the profile editor" do
        expect(action.at_css("a[href='#{edit_profile_path}']").text.strip).to eq(I18n.t("players.show.edit_profile"))
      end
    end

    context "when the viewer is an admin" do
      let(:viewer) { create(:user, :admin) }

      before do
        sign_in viewer
        get player_path(player)
      end

      it "links to the admin editor" do
        expect(action.at_css("a")["href"]).to include("/resources/players/#{player.to_param}/edit")
      end
    end

    context "when the viewer has a pending claim" do
      before do
        create(:player_claim, user: viewer, player:)
        sign_in viewer
        get player_path(player)
      end

      it "says the claim is pending" do
        expect(action.text.strip).to eq(I18n.t("players.show.claim_pending"))
      end
    end

    context "when the viewer has a pending dispute" do
      let_it_be(:owner) { create(:user) }

      before do
        owner.update!(player:)
        create(:player_claim, :dispute, user: viewer, player:)
        sign_in viewer
        get player_path(player)
      end

      after { owner.update!(player: nil) }

      it "says the dispute is pending" do
        expect(action.text.strip).to eq(I18n.t("players.show.dispute_pending"))
      end
    end

    context "when someone else owns the profile" do
      let_it_be(:owner) { create(:user) }

      before do
        owner.update!(player:)
        sign_in viewer
        get player_path(player)
      end

      after { owner.update!(player: nil) }

      it "offers a dispute" do
        expect(action.at_css("a[href='#{new_player_dispute_path(player)}']").text.strip)
          .to eq(I18n.t("players.show.dispute_player"))
      end
    end

    context "when the profile is unclaimed" do
      before do
        sign_in viewer
        get player_path(player)
      end

      it "offers a claim button with a confirmation" do
        expect(action.at_css("form[action='#{player_claim_path(player)}'] button")["data-turbo-confirm"])
          .to eq(I18n.t("players.show.claim_confirm"))
      end

      it "styles the claim as the primary button" do
        expect(action.at_css("button")["class"]).to include("vm-btn--primary")
      end
    end
  end

  describe "awards" do
    let_it_be(:staff_award) { create(:award, title: "Организатор", staff: true) }
    let_it_be(:repeated_award) { create(:award, title: "Почётный трупак") }
    let_it_be(:old_season) { create(:competition, :season, name: "Сезон 3") }

    before_all do
      create(:player_award, player:, award: repeated_award, competition: season, position: 1)
      create(:player_award, player:, award: repeated_award, competition: old_season, position: 2)
      create(:player_award, player:, award: staff_award, position: 3)
    end

    before { get player_path(player) }

    it "shows the awards count, repeat wins included" do
      expect(number.("awards").text.squish).to eq("3 #{I18n.t('players.redesign.numbers.awards', count: 3)}")
    end

    it "shows one badge per award, staff first" do
      expect(badges.map { |badge| badge.at_css("[data-part='title']").text.strip }).to eq([ "Организатор", "Почётный трупак" ])
    end

    it "marks the staff badge" do
      expect(badges.first["data-award"]).to eq("staff")
    end

    it "shows no competitions under a staff badge" do
      expect(badges.first.at_css(".vm-sub")).to be_nil
    end

    it "lists the competitions of a repeated award" do
      expect(badges.last.at_css(".vm-sub").text.strip).to eq("Сезон 5, Сезон 3")
    end
  end

  describe "roles" do
    before { get player_path(player) }

    it "shows a card per role with games and win rate" do
      expect(roles.css("[data-role]").map { |card| card.text.squish })
        .to contain_exactly("Мирный 1 #{I18n.t('players.redesign.numbers.games', count: 1)} · 100.0%",
                            "Мафия 1 #{I18n.t('players.redesign.numbers.games', count: 1)} · 0.0%")
    end

    it "shows the role icon" do
      expect(roles.at_css("[data-role='peace'] img")["src"]).to include("roles/peace")
    end
  end

  describe "bio" do
    before { get player_path(player) }

    it "shows the bio keeping line breaks" do
      expect(document.at_css("#player-bio").text).to include("Играю с первого сезона.\nЛюблю шерифа.")
    end
  end

  describe "section order" do
    let_it_be(:award) { create(:award, title: "Глаз-алмаз") }

    before_all { create(:player_award, player:, award:) }

    before do
      article = create(:news, :published, title: "Про Финчера")
      article.player_mentions.create!(player:)
      get player_path(player)
    end

    it "follows the approved mockup: awards, roles, bio, competitions, news" do
      expect(document.css("main section").map { |section| section["id"] })
        .to eq(%w[player-awards player-roles player-bio player-competitions player-news])
    end
  end

  describe "an award with an SVG icon" do
    let_it_be(:svg_award) { create(:award, title: "Векторная") }

    before_all do
      svg_award.icon.attach(io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"/>'),
                            filename: "icon.svg", content_type: "image/svg+xml")
      create(:player_award, player:, award: svg_award)
    end

    before { get player_path(player) }

    it "renders the page with the icon" do
      expect(awards.at_css("[data-award] img")["src"]).to include("icon.svg")
    end
  end

  describe "database queries" do
    let_it_be(:busy_player) { create(:player, name: "Завсегдатай") }
    let_it_be(:quiet_player) { create(:player, name: "Редкий") }
    let_it_be(:sheriff) { create(:role, code: "sheriff", name: "Шериф") }
    let_it_be(:don) { create(:role, code: "don", name: "Дон") }
    let(:queries_for) do
      lambda do |profile|
        count = 0
        counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] }
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get player_path(profile) }
        count
      end
    end

    # Each game sits in its own series with its own role, so a lazy load per row is a fresh query, never a cache hit.
    # The quiet player has two games, not one: with one, `id = ?` lookups repeat verbatim and the cache hides them.
    before_all do
      roles = [ peace, mafia, sheriff, don ]
      games = Array.new(4) { |i| create(:game, competition: create(:competition, :series, parent: season), result: "draw", game_number: 50 + i) }
      games.first(2).each_with_index { |game, i| create(:game_participation, game:, player: quiet_player, role: roles[i]) }
      games.each_with_index { |game, i| create(:game_participation, game:, player: busy_player, role: roles[i]) }
      2.times do |i|
        game = create(:game, competition: create(:competition, :series, parent: season), result: "draw", game_number: 60 + i)
        create(:game_participation, game:, player: busy_player, role: roles[i])
      end
    end

    it "does not grow with the number of games" do
      expect(queries_for.(busy_player)).to eq(queries_for.(quiet_player))
    end
  end

  describe "news" do
    let_it_be(:article) { create(:news, :published, title: "Итоги сезона") }

    before do
      article.player_mentions.create!(player:)
      get player_path(player)
    end

    it "shows news mentioning the player" do
      expect(document.at_css("#player-news").text).to include("Итоги сезона")
    end
  end

  describe "competitions" do
    let(:section) { document.at_css("#player-competitions") }
    let(:rows) { section.css("details") }
    let(:row) { ->(name) { rows.find { |details| details.at_css("summary [data-part='name']").text.include?(name) } } }
    let(:game_rows) { ->(name) { row.(name).css("tbody tr") } }
    let(:game_row) { ->(name, label) { game_rows.(name).find { |tr| tr.at_css("[data-column='game'] a").text.squish == label } } }

    let_it_be(:racer) { create(:player, name: "Гонщик") }
    let_it_be(:rival) { create(:player, name: "Соперник") }
    let_it_be(:finished) do
      create(:competition, :season, name: "Сезон 4", started_on: Date.new(2025, 5, 31), ended_on: Date.new(2025, 8, 16))
    end
    let_it_be(:finished_series) { create(:competition, :series, parent: finished, name: "Серия 2") }
    let_it_be(:running) { create(:competition, :season, name: "Сезон 6", started_on: Date.new(2026, 9, 1)) }
    let_it_be(:running_series) { create(:competition, :series, parent: running, name: "Серия 9") }
    let_it_be(:cup) do
      create(:competition, :minicup, name: "Кубок", started_on: Date.new(2024, 3, 1), ended_on: Date.new(2024, 3, 2))
    end
    let_it_be(:won_game) do
      create(:game, competition: finished_series, game_number: 1, played_on: Date.new(2025, 6, 7), result: "peace_victory")
    end
    let_it_be(:lost_game) do
      create(:game, competition: finished_series, game_number: 2, played_on: Date.new(2025, 6, 14), result: "mafia_victory")
    end
    let_it_be(:root_game) do
      create(:game, competition: finished, game_number: 7, played_on: Date.new(2025, 6, 21), result: "draw")
    end
    let_it_be(:live_game) do
      create(:game, competition: running_series, game_number: 3, played_on: Date.new(2026, 9, 5), result: "in_progress",
                    hide_roles: true)
    end
    let_it_be(:cup_game) { create(:game, competition: cup, game_number: 1, played_on: Date.new(2024, 3, 1), result: "draw") }

    before_all do
      create(:game_participation, game: won_game, player: racer, role: peace, win: true, plus: 1.5)
      create(:game_participation, game: lost_game, player: racer, role: peace, plus: 0.5, minus: 0.25)
      create(:game_participation, game: root_game, player: racer, role: peace, plus: 0.5)
      create(:game_participation, game: won_game, player: rival, role: peace, win: true, plus: 5)
      create(:game_participation, game: live_game, player: racer, role: mafia, win: true, plus: 1)
      create(:game_participation, game: cup_game, player: racer, role: peace, plus: 0)
      4.times { create(:game_participation, game: cup_game, player: create(:player), role: mafia, plus: 1) }
    end

    before { get player_path(racer) }

    it "labels the section" do
      expect(section.at_css(".vm-label").text.strip).to eq(I18n.t("players.redesign.competitions"))
    end

    it "lists running competitions first, then the newest finished" do
      expect(rows.map { |details| details.at_css("summary [data-part='name'] a").text.strip })
        .to eq([ "Сезон 6", "Сезон 4", "Кубок" ])
    end

    it "opens only the first competition" do
      expect(rows.map { |details| details.key?("open") }).to eq([ true, false, false ])
    end

    it "links the competition name" do
      expect(row.("Сезон 4").at_css("summary a")["href"]).to eq(competition_path(slug: finished.slug))
    end

    it "marks a running competition" do
      expect(row.("Сезон 6").at_css("summary .vm-pill").text.strip).to eq(I18n.t("players.redesign.running"))
    end

    it "does not mark a finished competition" do
      expect(row.("Сезон 4").at_css("summary .vm-pill")).to be_nil
    end

    it "shows the place out of the ranked players" do
      expect(row.("Сезон 4").at_css("[data-column='place']").text.squish)
        .to eq("2 #{I18n.t('players.redesign.place_of', count: 2)}")
    end

    it "colours a top-three place" do
      expect(row.("Сезон 4").at_css("[data-column='place'] .vm-medal")["class"]).to include("vm-medal--2")
    end

    it "colours first place gold" do
      expect(row.("Сезон 6").at_css("[data-column='place'] .vm-medal")["class"]).to include("vm-medal--1")
    end

    it "leaves a place below third plain" do
      expect(row.("Кубок").at_css("[data-column='place'] .vm-medal")["class"]).not_to include("vm-medal--")
    end

    it "shows games, wins and rating" do
      expect(%w[games wins rating].map { |column| row.("Сезон 4").at_css("summary [data-column='#{column}']").text.strip })
        .to eq(%w[3 1 2.25])
    end

    it "folds games and wins under the name for phones" do
      expect(row.("Сезон 4").at_css("summary [data-part='name'] .vm-sub").text.squish)
        .to eq("#{I18n.t('players.redesign.summary_sub.games', count: 3)} · #{I18n.t('players.redesign.summary_sub.wins', count: 1)}")
    end

    it "lists games newest first" do
      expect(game_rows.("Сезон 4").map { |tr| tr.at_css("[data-column='game'] a").text.squish })
        .to eq([ "Игра 7", "Серия 2 · Игра 2", "Серия 2 · Игра 1" ])
    end

    it "links each game" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 1").at_css("[data-column='game'] a")["href"]).to eq(game_path(won_game))
    end

    it "shows the date in the visitor's format" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 1").at_css("[data-column='date']").text.strip)
        .to eq(DatetimeFormatter.call(Date.new(2025, 6, 7), type: :date))
    end

    it "shows the role" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 1").at_css("[data-column='role']").text.strip).to eq("Мирный")
    end

    it "shows a gold pill for a win" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 1").at_css("[data-column='result'] .vm-pill")["class"])
        .to include("vm-pill--gold")
    end

    it "highlights a won game" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 1")["class"]).to include("vm-row--highlight")
    end

    it "shows a plain pill for a loss" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 2").at_css("[data-column='result']").text.strip)
        .to eq(I18n.t("players.redesign.result.lose"))
    end

    it "does not highlight a lost game" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 2")["class"].to_s).not_to include("vm-row--highlight")
    end

    it "shows a neutral pill for a draw" do
      expect(game_row.("Сезон 4", "Игра 7").at_css("[data-column='result'] .vm-pill")["class"]).to include("vm-pill--neutral")
    end

    it "shows the game's total" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 2").at_css("[data-column='score']").text.strip).to eq("0.25")
    end

    context "with a running game whose roles are hidden" do
      let(:live_row) { game_row.("Сезон 6", "Серия 9 · Игра 3") }

      it "hides the role" do
        expect(live_row.at_css("[data-column='role']").text.strip).to be_empty
      end

      it "hides the result" do
        expect(live_row.at_css("[data-column='result']").text.strip).to be_empty
      end

      it "does not highlight the row even though the win is stored" do
        expect(live_row["class"].to_s).not_to include("vm-row--highlight")
      end

      it "hides the score" do
        expect(live_row.at_css("[data-column='score']").text.strip).to be_empty
      end

      it "folds a date without a result for phones" do
        expect(live_row.at_css("[data-column='game'] .vm-sub").text.squish)
          .to eq(DatetimeFormatter.call(Date.new(2026, 9, 5), type: :date))
      end
    end

    it "folds date and result for phones" do
      expect(game_row.("Сезон 4", "Серия 2 · Игра 1").at_css("[data-column='game'] .vm-sub").text.squish)
        .to eq("#{DatetimeFormatter.call(Date.new(2025, 6, 7), type: :date)} · #{I18n.t('players.redesign.result.win').downcase}")
    end
  end

  context "when the player has nothing but a name" do
    let_it_be(:bare_player) { create(:player, name: "Новичок") }

    before { get player_path(bare_player) }

    it "renders no empty sections" do
      expect(section_labels).to be_empty
    end

    it "does not say when the player started" do
      expect(document.at_css("#player-since")).to be_nil
    end

    it "says there are no games yet" do
      expect(document.at_css("#player-no-games").text.strip).to eq(I18n.t("players.redesign.no_games"))
    end

    it "shows zero games" do
      expect(number.("games").text.squish).to eq("0 #{I18n.t('players.redesign.numbers.games', count: 0)}")
    end
  end
end
