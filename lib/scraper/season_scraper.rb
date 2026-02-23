module Scraper
  class SeasonScraper < Base
    def scrape_all
      games = []

      (1..5).each do |season|
        doc = fetch("/season/#{season}")
        next unless doc

        games.concat(parse_season(doc, season))
      end

      games
    end

    private

    def parse_season(doc, season)
      games = []
      table = doc.at_css("td.content .table.small")
      return games unless table

      table.css(".row:not(.header)").each do |row|
        cells = row.css(".cell")
        next if cells.size < 4

        date = cells[0].text.strip
        series = cells[2].text.strip.to_i

        cells[3].css("a").each do |link|
          href = link["href"]
          next unless href&.start_with?("/game/")

          game_id = href.delete_prefix("/game/").to_i
          game_number = link.text.strip.to_i

          games << {
            id: game_id,
            played_on: date,
            season: season,
            series: series,
            game_number: game_number
          }
        end
      end

      log "Season #{season}: found #{games.size} games"
      games
    end
  end
end
