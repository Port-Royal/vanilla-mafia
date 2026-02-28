require "rails_helper"
require_relative "../../../lib/scraper/base"

RSpec.describe Scraper::Base do
  subject(:scraper) { described_class.new }

  describe "#fetch" do
    context "when request succeeds" do
      before do
        response = instance_double(Net::HTTPSuccess, body: "<html><body>OK</body></html>")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:get).and_return(response)
        allow(scraper).to receive(:sleep)
      end

      it "returns a Nokogiri document" do
        doc = scraper.fetch("/test")
        expect(doc).to be_a(Nokogiri::HTML::Document)
        expect(doc.text).to include("OK")
      end
    end

    context "when request returns non-success" do
      before do
        response = instance_double(Net::HTTPNotFound, code: "404")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:get).and_return(response)
      end

      it "returns nil" do
        expect(scraper.fetch("/test")).to be_nil
      end
    end

    context "when network error occurs" do
      before do
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:get).and_raise(SocketError, "connection refused")
      end

      it "returns nil" do
        expect(scraper.fetch("/test")).to be_nil
      end
    end

    context "when timeout occurs" do
      before do
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:get).and_raise(Net::ReadTimeout)
      end

      it "returns nil" do
        expect(scraper.fetch("/test")).to be_nil
      end
    end
  end

  describe "#parse_decimal (private)" do
    it "parses a decimal string" do
      expect(scraper.send(:parse_decimal, "1.5")).to eq(BigDecimal("1.5"))
    end

    it "returns nil for empty string" do
      expect(scraper.send(:parse_decimal, "")).to be_nil
    end

    it "returns nil for whitespace-only string" do
      expect(scraper.send(:parse_decimal, "  ")).to be_nil
    end

    it "handles integer strings" do
      expect(scraper.send(:parse_decimal, "3")).to eq(BigDecimal("3"))
    end
  end

  describe "#normalize (private)" do
    it "normalizes NFD to NFC" do
      # й as и + combining breve (NFD)
      nfd = "\u0438\u0306"
      expect(scraper.send(:normalize, nfd)).to eq("й")
    end

    it "strips whitespace" do
      expect(scraper.send(:normalize, "  hello  ")).to eq("hello")
    end
  end
end
