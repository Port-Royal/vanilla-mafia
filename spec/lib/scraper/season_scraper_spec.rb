require "rails_helper"
require_relative "../../../lib/scraper/season_scraper"

RSpec.describe Scraper::SeasonScraper do
  subject(:scraper) { described_class.new }

  let(:fixture) { File.read(Rails.root.join("spec/fixtures/scraper/season.html")) }
  let(:doc) { Nokogiri::HTML(fixture) }

  describe "#scrape_all" do
    before do
      allow(scraper).to receive(:fetch).and_return(doc)
    end

    it "returns games from all requested seasons" do
      games = scraper.scrape_all(seasons: [ 1 ])
      expect(games.size).to eq(3)
    end

    it "parses game attributes correctly" do
      games = scraper.scrape_all(seasons: [ 1 ])
      first = games.first

      expect(first[:id]).to eq(101)
      expect(first[:played_on]).to eq(Date.new(2026, 1, 15))
      expect(first[:season]).to eq(1)
      expect(first[:series]).to eq(1)
      expect(first[:game_number]).to eq(1)
    end

    it "extracts multiple games from same row" do
      games = scraper.scrape_all(seasons: [ 1 ])
      series1_games = games.select { |g| g[:series] == 1 }
      expect(series1_games.size).to eq(2)
    end

    context "when fetch returns nil" do
      before do
        allow(scraper).to receive(:fetch).and_return(nil)
      end

      it "returns empty array" do
        expect(scraper.scrape_all(seasons: [ 1 ])).to eq([])
      end
    end

    context "when page has no table" do
      let(:doc) { Nokogiri::HTML("<html><body><td class='content'></td></body></html>") }

      it "returns empty array" do
        expect(scraper.scrape_all(seasons: [ 1 ])).to eq([])
      end
    end
  end
end
