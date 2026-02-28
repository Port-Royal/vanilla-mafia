require "rails_helper"
require_relative "../../../lib/scraper/player_scraper"

RSpec.describe Scraper::PlayerScraper do
  subject(:scraper) { described_class.new }

  let(:fixture) { File.read(Rails.root.join("spec/fixtures/scraper/player.html")) }
  let(:doc) { Nokogiri::HTML(fixture) }

  describe "#scrape" do
    before do
      allow(scraper).to receive(:fetch).and_return(doc)
    end

    it "extracts photo data" do
      result = scraper.scrape(1)

      expect(result).not_to be_nil
      expect(result[:content_type]).to eq("image/jpeg")
      expect(result[:data]).to be_a(String)
    end

    context "when fetch returns nil" do
      before do
        allow(scraper).to receive(:fetch).and_return(nil)
      end

      it "returns nil" do
        expect(scraper.scrape(1)).to be_nil
      end
    end

    context "when page has no photo div" do
      let(:doc) { Nokogiri::HTML("<html><body></body></html>") }

      it "returns nil" do
        expect(scraper.scrape(1)).to be_nil
      end
    end

    context "when photo has unsupported content type" do
      let(:doc) do
        Nokogiri::HTML('<html><body><div class="playerPhoto" style="background-image: url(\'data:image/svg+xml;base64,PHN2Zz4=\')"></div></body></html>')
      end

      it "returns nil" do
        expect(scraper.scrape(1)).to be_nil
      end
    end

    context "when base64 data is invalid" do
      let(:doc) do
        Nokogiri::HTML('<html><body><div class="playerPhoto" style="background-image: url(\'data:image/jpeg;base64,!!!invalid!!!\')"></div></body></html>')
      end

      it "returns nil" do
        expect(scraper.scrape(1)).to be_nil
      end
    end
  end
end
