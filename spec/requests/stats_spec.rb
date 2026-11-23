require "rails_helper"

RSpec.describe "Stats page" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:main) { document.at_css("main#site-main") }
  let(:number) { ->(name) { document.at_css("#stats-numbers [data-number='#{name}']") } }
  let(:share) { ->(result) { document.at_css("#stats-results [data-result='#{result}']") } }
  let(:rows) { document.css("#stats-competitions tbody tr") }
  let(:row) { ->(competition) { document.at_css("#stats-competitions tr[data-competition-id='#{competition.id}']") } }
  let(:cell) { ->(competition, column) { row.(competition).at_css("[data-column='#{column}']") } }

  before { get stats_path }


  context "without data" do
    it { expect(response).to have_http_status(:ok) }
    it { expect(main.at_css("h1").text).to eq(I18n.t("home.stats.title")) }
    it { expect(document.at_css("#stats-since")).to be_nil }
    it { expect(number.(:players).at_css("[data-part='value']").text).to eq("0") }
    it { expect(document.at_css("#stats-results")).to be_nil }
    it { expect(document.at_css("#stats-competitions table")).to be_nil }
    it { expect(document.at_css("#stats-empty").text.strip).to eq(I18n.t("stats.show.empty")) }
  end

  context "with games" do
    let_it_be(:season) { create(:competition, :season, name: "Сезон 5", position: 1, ended_on: Date.new(2024, 6, 1)) }
    let_it_be(:running) { create(:competition, :season, name: "Сезон 6", position: 2) }
    let_it_be(:season_series) { create(:competition, :series, parent: season) }
    let_it_be(:running_series) { create(:competition, :series, parent: running) }
    let_it_be(:alice) { create(:player) }
    let_it_be(:bob) { create(:player) }

    let_it_be(:games) do
      [
        create(:game, competition: season_series, result: "peace_victory", played_on: Date.new(2024, 1, 13)),
        create(:game, competition: season_series, result: "mafia_victory", played_on: Date.new(2024, 2, 1)),
        create(:game, competition: running_series, result: "mafia_victory", played_on: Date.new(2025, 1, 1))
      ]
    end

    let_it_be(:participations) do
      [
        create(:game_participation, game: games[0], player: alice),
        create(:game_participation, game: games[0], player: bob),
        create(:game_participation, game: games[2], player: alice)
      ]
    end

    it "shows when the club started playing" do
      expect(document.at_css("#stats-since").text.strip).to eq(I18n.t("stats.show.since", date: "13.01.2024"))
    end

    describe "numbers" do
      it { expect(number.(:players).at_css("[data-part='value']").text).to eq("2") }
      it { expect(number.(:players).at_css("[data-part='label']").text).to eq(I18n.t("home.stats.players")) }
      it { expect(number.(:games).at_css("[data-part='value']").text).to eq("3") }
      it { expect(number.(:games).at_css("[data-part='label']").text).to eq(I18n.t("home.stats.games")) }
      it { expect(number.(:competitions).at_css("[data-part='value']").text).to eq("1") }
      it { expect(number.(:competitions).at_css("[data-part='label']").text).to eq(I18n.t("home.stats.competitions")) }
    end

    describe "who wins" do
      it { expect(document.at_css("#stats-results h2").text).to eq(I18n.t("stats.show.results")) }
      it { expect(share.(:peace_victory).at_css("[data-part='label']").text).to eq(I18n.t("stats.show.peace_victory")) }
      it { expect(share.(:peace_victory).at_css("[data-part='count']").text).to eq("1") }
      it { expect(share.(:peace_victory).at_css("[data-part='share']").text).to eq("33%") }
      it { expect(share.(:mafia_victory).at_css("[data-part='label']").text).to eq(I18n.t("stats.show.mafia_victory")) }
      it { expect(share.(:mafia_victory).at_css("[data-part='count']").text).to eq("2") }
      it { expect(share.(:mafia_victory).at_css("[data-part='share']").text).to eq("67%") }
      it { expect(share.(:draw)).to be_nil }

      it "draws the bar from the counts" do
        expect(document.css("#stats-results [data-bar]").map { |segment| [ segment["data-bar"], segment["style"] ] })
          .to eq([ %w[peace_victory flex-grow:1], %w[mafia_victory flex-grow:2] ])
      end

      it { expect(document.at_css("#stats-results [data-bar]").parent["aria-hidden"]).to eq("true") }

      context "when a game ended in a draw" do
        let_it_be(:draw) { create(:game, competition: season_series, result: "draw") }

        it { expect(share.(:draw).at_css("[data-part='label']").text).to eq(I18n.t("stats.show.draw")) }
        it { expect(share.(:draw).at_css("[data-part='count']").text).to eq("1") }
        it { expect(share.(:draw).at_css("[data-part='share']").text).to eq("25%") }
        it { expect(document.css("#stats-results [data-bar]").pluck("data-bar")).to include("draw") }
      end
    end

    describe "by competition" do
      it { expect(document.at_css("#stats-competitions h2").text).to eq(I18n.t("stats.show.competitions")) }
      it { expect(document.at_css("#stats-empty")).to be_nil }

      it "lists the competitions newest first" do
        expect(rows.pluck("data-competition-id")).to eq([ running.id, season.id ].map(&:to_s))
      end

      it "links each competition" do
        expect(row.(season).at_css("a[href='#{competition_path(slug: season.slug)}']").text).to eq("Сезон 5")
      end

      it { expect(cell.(season, :games).text).to eq("2") }
      it { expect(cell.(season, :players).text).to eq("2") }
      it { expect(cell.(season, :peace_wins).text).to eq("1") }
      it { expect(cell.(season, :mafia_wins).text).to eq("1") }
      it { expect(cell.(running, :players).text).to eq("1") }

      it "folds the wins under the name on phones" do
        expect(row.(season).at_css(".vm-sub").text.squish)
          .to eq("#{I18n.t('stats.show.peace_wins')} 1 · #{I18n.t('stats.show.mafia_wins')} 1")
      end

      it { expect(row.(running).at_css(".vm-pill").text.strip).to eq(I18n.t("stats.show.running")) }
      it { expect(row.(season).at_css(".vm-pill")).to be_nil }
    end
  end
end
