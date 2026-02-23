require "net/http"
require "nokogiri"

module Scraper
  BASE_URL = "https://chimafia.org"
  DELAY = 0.5

  class Base
    def fetch(path)
      uri = URI("#{BASE_URL}#{path}")
      log "Fetching #{uri}"
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        log "ERROR: #{response.code} for #{uri}"
        return nil
      end

      sleep DELAY
      Nokogiri::HTML(response.body)
    end

    def log(msg)
      puts "[#{Time.current.strftime('%H:%M:%S')}] #{msg}"
    end

    private

    def parse_decimal(text)
      text = text.to_s.strip
      return nil if text.empty?

      text.to_f
    end

    # Normalize NFD → NFC to handle decomposed Cyrillic (й = и+̆, ё = е+̈)
    def normalize(text)
      text.to_s.strip.unicode_normalize(:nfc)
    end
  end
end
