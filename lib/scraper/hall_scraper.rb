module Scraper
  class HallScraper < Base
    def scrape
      doc = fetch("/hall")
      return { awards: [], player_awards: [], staff_awards: [] } unless doc

      awards = parse_award_definitions(doc)
      player_awards = parse_player_awards(doc)
      staff_awards = parse_staff_awards(doc)

      {
        awards: awards,
        player_awards: player_awards,
        staff_awards: staff_awards
      }
    end

    private

    def parse_award_definitions(doc)
      awards = []
      definitions_div = doc.css("div.hall.awards-list")
      return awards unless definitions_div.any?

      definitions_div.css("div.award").each_with_index do |award_div, index|
        img = award_div.at_css("img")
        desc_div = award_div.css("div").last
        description = desc_div ? normalize(desc_div.text) : nil

        # Extract title from the description start
        title = extract_title_from_description(description)
        icon_data = img ? img["src"] : nil

        awards << {
          title: title,
          description: description,
          icon_data: icon_data,
          position: index + 1,
          staff: false
        }
      end

      log "Found #{awards.size} award definitions"
      awards
    end

    TITLE_MAP = {
      "Победитель сезона" => "Победитель",
      "Лучший игрок" => "Лучший игрок",
      'Звание "Любимый игрок"' => "Любимый игрок",
      "Примерный горожанин" => "Самый примерный горожанин",
      "Коварный мафиози" => "Самый коварный мафиози",
      "Отважный шериф" => "Самый отважный шериф",
      "Крёстный отец" => "Крёстный отец",
      "Непризнанный гений" => "Непризнанный гений",
      "Глаз-алмаз" => "Глаз-алмаз",
      "Почётный трупак" => "Почётный трупак",
      'Награда "Вот это поворот"' => "Вот это поворот! Автор самой эпичной ошибки"
    }.freeze

    def extract_title_from_description(description)
      return nil unless description

      # Normalize Unicode typographic quotes to ASCII
      normalized = description.gsub(/[\u201C\u201D\u00AB\u00BB]/, '"')
      TITLE_MAP.each do |prefix, title|
        return title if normalized.start_with?(prefix)
      end

      log "WARNING: Unknown award description: #{description[0..50]}"
      description.split(" - ").first
    end

    def parse_player_awards(doc)
      awards = []
      # First div.hall (before "Все награды") contains player awards
      hall_div = doc.at_css("td.content div.hall")
      return awards unless hall_div

      hall_div.css("a").each do |link|
        href = link["href"]
        next unless href&.start_with?("/player/")

        player_id = href.delete_prefix("/player/").to_i

        link.css("span.award img").each do |img|
          title_text = normalize(img["title"])
          alt_text = normalize(img["alt"])

          season = extract_season(title_text)

          awards << {
            player_id: player_id,
            award_title: alt_text,
            season: season
          }
        end
      end

      log "Found #{awards.size} player award entries"
      awards
    end

    def find_staff_div(doc)
      doc.css("td.content *").each do |node|
        next unless node.name.match?(/\Ah[1-4]\z/)
        next unless normalize(node.text).include?("Команда организаторов")

        sibling = node.next_element
        sibling = sibling.next_element while sibling && !sibling.matches?("div.hall")
        return sibling
      end
      nil
    end

    def parse_staff_awards(doc)
      awards = []
      staff_div = find_staff_div(doc)
      return awards unless staff_div

      staff_div.css("a").each do |link|
        href = link["href"]
        next unless href&.start_with?("/player/")

        player_id = href.delete_prefix("/player/").to_i

        link.css("span.award img").each do |img|
          alt_text = normalize(img["alt"])

          awards << {
            player_id: player_id,
            award_title: alt_text,
            staff: true
          }
        end
      end

      log "Found #{awards.size} staff award entries"
      awards
    end

    def extract_season(title_text)
      match = title_text.match(/(\d+)\s*[cс]езона/)
      match ? match[1].to_i : nil
    end
  end
end
