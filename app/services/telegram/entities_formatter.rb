module Telegram
  class EntitiesFormatter
    TAG_MAP = {
      "bold" => "strong",
      "italic" => "em",
      "strikethrough" => "del",
      "code" => "code",
      "pre" => "pre"
    }.freeze

    def self.call(text, entities)
      new(text, entities).call
    end

    def initialize(text, entities)
      @text = text || ""
      @entities = (entities || []).sort_by { |e| [ e["offset"], -e["length"] ] }
    end

    def call
      return "" if @text.blank?
      return text_to_html(@text.strip) if @entities.empty?

      build_html.strip
    end

    private

    def build_html
      offset_map = build_offset_map(@text)

      opens = Hash.new { |h, k| h[k] = [] }
      closes = Hash.new { |h, k| h[k] = [] }

      @entities.each do |entity|
        open_tag, close_tag = tags_for(entity)
        next unless open_tag

        start_char = offset_map[entity["offset"]]
        end_char = offset_map[entity["offset"] + entity["length"]]
        next if start_char.nil? || end_char.nil?

        opens[start_char] << open_tag
        closes[end_char].unshift(close_tag)
      end

      pre_ranges = build_pre_ranges(offset_map)

      result = []
      @text.each_char.with_index do |char, i|
        closes[i].each { |t| result << t }
        opens[i].each { |t| result << t }
        result << format_char(char, inside_pre?(i, pre_ranges))
      end
      closes[@text.length].each { |t| result << t }

      result.join
    end

    def build_offset_map(text)
      map = {}
      utf16_pos = 0
      text.each_char.with_index do |char, idx|
        map[utf16_pos] = idx
        utf16_pos += char.encode("UTF-16LE").bytesize / 2
      end
      map[utf16_pos] = text.length
      map
    end

    def tags_for(entity)
      type = entity["type"]

      
    end

    def build_pre_ranges(offset_map)
      @entities
        .select { |e| e["type"] == "pre" }
        .filter_map do |entity|
          start_char = offset_map[entity["offset"]]
          end_char = offset_map[entity["offset"] + entity["length"]]
          (start_char...end_char) if start_char && end_char
        end
    end

    def inside_pre?(index, pre_ranges)
      pre_ranges.any? { |range| range.cover?(index) }
    end

    def format_char(char, inside_pre)
      if char == "\n" && !inside_pre
        "<br>"
      else
        ERB::Util.html_escape(char)
      end
    end

    def text_to_html(text)
      ERB::Util.html_escape(text).gsub("\n", "<br>")
    end
  end
end
