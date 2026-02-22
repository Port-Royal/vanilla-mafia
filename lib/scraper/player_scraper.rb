require "base64"

module Scraper
  class PlayerScraper < Base
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
      base64_data = match[2].sub(/['");]+\z/, "") # strip any trailing quotes/parens
      binary_data = Base64.decode64(base64_data)

      { content_type: content_type, data: binary_data }
    end
  end
end
