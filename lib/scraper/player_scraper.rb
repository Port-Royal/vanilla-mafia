require "base64"

module Scraper
  class PlayerScraper < Base
    ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

    def scrape(player_id)
      doc = fetch("/player/#{player_id}")
      return nil unless doc

      photo_data = extract_photo(doc)
      return nil unless photo_data

      photo_data
    end

    private

    def extract_photo(doc)
      photo_div = doc.at_css("div.playerPhoto")
      return nil unless photo_div

      style = photo_div["style"].to_s
      # The site's HTML is malformed: Nokogiri truncates the style at the closing "
      # so the url('...') may not have its closing quote/paren. Match greedily.
      match = style.match(/background-image:\s*url\('?data:image\/([^;]+);base64,(.+)/m)
      return nil unless match

      content_type = "image/#{match[1]}"
      return nil unless ALLOWED_CONTENT_TYPES.include?(content_type)

      base64_data = match[2].sub(/['");]+\z/, "") # strip any trailing quotes/parens
      binary_data = Base64.strict_decode64(base64_data)

      { content_type: content_type, data: binary_data }
    rescue ArgumentError => e
      log "ERROR: Invalid base64 for photo: #{e.message}"
      nil
    end
  end
end
