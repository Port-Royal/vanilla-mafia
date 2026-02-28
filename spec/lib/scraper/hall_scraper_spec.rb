require "rails_helper"
require_relative "../../../lib/scraper/hall_scraper"

RSpec.describe Scraper::HallScraper do
  subject(:scraper) { described_class.new }

  let(:fixture) { File.read(Rails.root.join("spec/fixtures/scraper/hall.html")) }
  let(:doc) { Nokogiri::HTML(fixture) }

  describe "#scrape" do
    before do
      allow(scraper).to receive(:fetch).and_return(doc)
    end

    it "parses award definitions" do
      result = scraper.scrape
      awards = result[:awards]

      expect(awards.size).to eq(2)
      expect(awards[0][:title]).to eq("Победитель")
      expect(awards[0][:position]).to eq(1)
      expect(awards[1][:title]).to eq("Лучший игрок")
      expect(awards[1][:position]).to eq(2)
    end

    it "extracts icon data URIs" do
      result = scraper.scrape
      expect(result[:awards][0][:icon_data]).to start_with("data:image/png;base64,")
    end

    it "parses player awards with season" do
      result = scraper.scrape
      player_awards = result[:player_awards]

      expect(player_awards.size).to eq(2)
      expect(player_awards[0][:player_id]).to eq(1)
      expect(player_awards[0][:award_title]).to eq("Победитель")
      expect(player_awards[0][:season]).to eq(1)
      expect(player_awards[1][:player_id]).to eq(2)
      expect(player_awards[1][:season]).to eq(2)
    end

    it "parses staff awards" do
      result = scraper.scrape
      staff_awards = result[:staff_awards]

      expect(staff_awards.size).to eq(1)
      expect(staff_awards[0][:player_id]).to eq(10)
      expect(staff_awards[0][:award_title]).to eq("Ведущий")
      expect(staff_awards[0][:staff]).to be true
    end

    context "when fetch returns nil" do
      before do
        allow(scraper).to receive(:fetch).and_return(nil)
      end

      it "returns empty collections" do
        result = scraper.scrape
        expect(result[:awards]).to eq([])
        expect(result[:player_awards]).to eq([])
      end
    end
  end
end
