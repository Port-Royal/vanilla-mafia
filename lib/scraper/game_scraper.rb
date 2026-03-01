module Scraper
  class GameScraper < Base
    ROLE_MAP = {
      "Мирный" => "peace",
      "Мафия" => "mafia",
      "Дон" => "don",
      "Шериф" => "sheriff"
    }.freeze

    PEACE_ROLES = %w[peace sheriff].freeze

    def scrape(game_info)
      doc = fetch("/game/#{game_info[:id]}")
      return nil unless doc

      name = parse_game_name(doc)
      participations = parse_participations(doc, game_info[:id])

      result = compute_result(participations)

      {
        game: game_info.merge(name: name, result: result),
        game_participations: participations
      }
    end

    private

    def parse_game_name(doc)
      h1 = doc.at_css("td.content h1")
      return nil unless h1

      text = normalize(h1.text)
      # Header format: "YYYY-MM-DD Сезон N Серия M Игра K [optional name]"
      # Extract optional name after the standard prefix
      match = text.match(/Игра\s+\d+\s+(.+)/)
      match ? match[1].strip : nil
    end

    def parse_participations(doc, game_id)
      participations = []
      table = doc.at_css("td.content .table.big")
      return participations unless table

      table.css(".row:not(.header)").each do |row|
        cells = row.css(".cell")
        next if cells.size < 10

        # Columns: [seat, player, role, win, plus, minus, best_move, extra, first_killed, total]
        player_link = cells[1].at_css("a")
        next unless player_link

        href = player_link["href"]
        next unless href&.start_with?("/player/")

        player_id = href.delete_prefix("/player/").to_i
        player_name = normalize(player_link.text)
        role_name = normalize(cells[2].text)
        role_code = ROLE_MAP[role_name]
        unless role_code
          log "WARNING: Unknown role '#{role_name}' in game #{game_id}"
          next
        end
        win = normalize(cells[3].text) == "Да"
        plus = parse_decimal(cells[4].text)
        minus = parse_decimal(cells[5].text)
        best_move = parse_decimal(cells[6].text)
        first_shoot = normalize(cells[8].text) == "Да"
        scraped_total = parse_decimal(cells[9].text)

        # Fold win bonus into plus so that total = plus - minus + best_move
        zero = BigDecimal("0")
        stored_plus = (plus || zero) + (win ? BigDecimal("1") : zero)
        stored_minus = minus || zero
        stored_best_move = best_move

        # Fold any remaining gap (e.g. season participation bonus) into plus
        if scraped_total
          computed = stored_plus - stored_minus + (stored_best_move || zero)
          gap = scraped_total - computed
          if gap.abs > BigDecimal("0.001")
            stored_plus += gap
            log "Game #{game_id}, #{player_name}: folded #{gap.round(2)} extra into plus"
          end
        end

        participations << {
          player_id: player_id,
          player_name: player_name,
          role_code: role_code,
          win: win,
          plus: stored_plus,
          minus: stored_minus,
          best_move: stored_best_move,
          first_shoot: first_shoot
        }
      end

      participations
    end

    def compute_result(participations)
      return nil if participations.empty?

      # Check if any peace-side player won
      peace_won = participations.any? { |r| PEACE_ROLES.include?(r[:role_code]) && r[:win] }
      peace_won ? "Победа мирных" : "Победа мафии"
    end
  end
end
