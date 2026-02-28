require "rails_helper"
require_relative "../../../lib/scraper/game_scraper"

RSpec.describe Scraper::GameScraper do
  subject(:scraper) { described_class.new }

  let(:fixture) { File.read(Rails.root.join("spec/fixtures/scraper/game.html")) }
  let(:doc) { Nokogiri::HTML(fixture) }
  let(:game_info) { { id: 101, played_on: Date.new(2026, 1, 15), season: 1, series: 1, game_number: 1 } }

  describe "#scrape" do
    before do
      allow(scraper).to receive(:fetch).and_return(doc)
    end

    it "returns game data with name and result" do
      result = scraper.scrape(game_info)

      expect(result[:game][:name]).to eq("Новогодняя")
      expect(result[:game][:result]).to eq("Победа мирных")
      expect(result[:game][:id]).to eq(101)
    end

    it "parses all player ratings" do
      result = scraper.scrape(game_info)
      expect(result[:ratings].size).to eq(3)
    end

    it "parses peace role correctly" do
      result = scraper.scrape(game_info)
      ivan = result[:ratings].find { |r| r[:player_name] == "Иван" }

      expect(ivan[:player_id]).to eq(1)
      expect(ivan[:role_code]).to eq("peace")
      expect(ivan[:win]).to be true
      expect(ivan[:first_shoot]).to be false
    end

    it "parses mafia role correctly" do
      result = scraper.scrape(game_info)
      maria = result[:ratings].find { |r| r[:player_name] == "Мария" }

      expect(maria[:player_id]).to eq(2)
      expect(maria[:role_code]).to eq("mafia")
      expect(maria[:win]).to be false
    end

    it "parses sheriff role correctly" do
      result = scraper.scrape(game_info)
      alexey = result[:ratings].find { |r| r[:player_name] == "Алексей" }

      expect(alexey[:role_code]).to eq("sheriff")
      expect(alexey[:win]).to be true
      expect(alexey[:first_shoot]).to be true
    end

    it "folds win bonus into plus" do
      result = scraper.scrape(game_info)
      ivan = result[:ratings].find { |r| r[:player_name] == "Иван" }

      # plus=0.5 + win_bonus=1.0 = 1.5
      expect(ivan[:plus]).to eq(BigDecimal("1.5"))
    end

    it "returns nil best_move when cell is empty" do
      result = scraper.scrape(game_info)
      maria = result[:ratings].find { |r| r[:player_name] == "Мария" }

      expect(maria[:best_move]).to be_nil
    end

    it "computes mafia victory when no peace players won" do
      mafia_html = fixture.gsub("Да", "Нет")
      allow(scraper).to receive(:fetch).and_return(Nokogiri::HTML(mafia_html))

      result = scraper.scrape(game_info)
      expect(result[:game][:result]).to eq("Победа мафии")
    end

    context "when fetch returns nil" do
      before do
        allow(scraper).to receive(:fetch).and_return(nil)
      end

      it "returns nil" do
        expect(scraper.scrape(game_info)).to be_nil
      end
    end

    context "when page has no ratings table" do
      let(:doc) { Nokogiri::HTML("<html><body><td class='content'><h1>Игра 1</h1></td></body></html>") }

      it "returns nil result for empty ratings" do
        result = scraper.scrape(game_info)
        expect(result[:ratings]).to be_empty
        expect(result[:game][:result]).to be_nil
      end
    end
  end
end
