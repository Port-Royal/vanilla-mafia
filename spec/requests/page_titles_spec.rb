require "rails_helper"

RSpec.describe "Page titles" do
  let(:title) { Nokogiri::HTML(response.body).at_css("head title").text }

  before { get path }

  context "with the home page" do
    let(:path) { root_path }

    it { expect(title).to eq("Vanilla Mafia") }
  end

  context "with a competition" do
    let_it_be(:competition) { create(:competition, :season, name: "Сезон 5 & финал") }
    let(:path) { competition_path(slug: competition.slug) }

    it { expect(title).to eq("Сезон 5 & финал — Vanilla Mafia") }
  end

  context "with a game" do
    let_it_be(:series) { create(:competition, :series, name: "Серия 2") }
    let_it_be(:game) { create(:game, competition: series, game_number: 7) }
    let(:path) { game_path(slug: game.slug) }

    it { expect(title).to eq("#{I18n.t('common.game')} 7 — Серия 2 — Vanilla Mafia") }
  end

  context "with a player" do
    let_it_be(:player) { create(:player, name: "Алиса") }
    let(:path) { player_path(slug: player.slug) }

    it { expect(title).to eq("Алиса — Vanilla Mafia") }
  end

  context "with the news list" do
    let(:path) { news_index_path }

    it { expect(title).to eq("#{I18n.t('news.index.title')} — Vanilla Mafia") }
  end

  context "with a news article" do
    let_it_be(:article) { create(:news, :published, title: "Итоги <сезона>") }
    let(:path) { news_path(slug: article.slug) }

    it { expect(title).to eq("Итоги <сезона> — Vanilla Mafia") }
  end

  context "with the hall of fame" do
    let(:path) { hall_path }

    it { expect(title).to eq("#{I18n.t('hall_of_fame.title')} — Vanilla Mafia") }
  end

  context "with the help index" do
    let(:path) { help_index_path }

    it { expect(title).to eq("#{I18n.t('help.index.title')} — Vanilla Mafia") }
  end

  context "with a help page" do
    let(:path) { help_path(slug: "obs-overlay") }

    it { expect(title).to eq("#{I18n.t('help.pages.obs-overlay.title')} — Vanilla Mafia") }
  end

  context "with the stats page" do
    let(:path) { stats_path }

    it { expect(title).to eq("#{I18n.t('home.stats.title')} — Vanilla Mafia") }
  end

  context "with the documents list" do
    let(:path) { documents_path }

    it { expect(title).to eq("#{I18n.t('documents.index.title')} — Vanilla Mafia") }
  end

  context "with a document" do
    let_it_be(:document) { create(:document, :published, title: "Правила игры") }
    let(:path) { document_path(slug: document.slug) }

    it { expect(title).to eq("Правила игры — Vanilla Mafia") }
  end
end
