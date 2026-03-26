module Telegram
  class MessageParser
    Result = Data.define(:text, :html_content, :from_id, :from_username, :from_first_name, :chat_id, :photo_file_id, :news) do
      def news?
        news
      end
    end

    NEWS_TAG_PATTERN = /#news\b/i

    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      @message = payload["message"] || payload["edited_message"]
    end

    def call
      return nil if @message.nil?

      raw_text = @message["text"] || @message["caption"] || ""
      raw_entities = @message["entities"] || @message["caption_entities"] || []
      news = NEWS_TAG_PATTERN.match?(raw_text)

      cleaned_text, adjusted_entities = strip_news_tags(raw_text, raw_entities)
      text = cleaned_text.squish
      html_content = Telegram::EntitiesFormatter.call(cleaned_text, adjusted_entities)

      from = @message["from"]

      Result.new(
        text: text,
        html_content: html_content,
        from_id: from&.dig("id"),
        from_username: from&.dig("username"),
        from_first_name: from&.dig("first_name"),
        chat_id: @message.dig("chat", "id"),
        photo_file_id: extract_largest_photo_id,
        news: news
      )
    end

    private

    def strip_news_tags(text, entities)
      matches = []
      text.scan(NEWS_TAG_PATTERN) { matches << [ Regexp.last_match.begin(0), Regexp.last_match.end(0) ] }

      return [ text, entities ] if matches.empty?

      char_to_utf16 = build_char_to_utf16_map(text)
      result_text = text.dup
      result_entities = entities.map { |e| e.dup }

      matches.reverse_each do |char_start, char_end|
        utf16_start = char_to_utf16[char_start]
        utf16_end = char_to_utf16[char_end]
        utf16_len = utf16_end - utf16_start

        result_text[char_start...char_end] = ""

        result_entities.each do |entity|
          ent_start = entity["offset"]
          ent_end = ent_start + entity["length"]

          if ent_start >= utf16_end
            entity["offset"] -= utf16_len
          elsif ent_start >= utf16_start && ent_end <= utf16_end
            entity["length"] = 0
          elsif ent_start < utf16_start && ent_end > utf16_end
            entity["length"] -= utf16_len
          end
        end

        result_entities.reject! { |e| e["length"] <= 0 }
      end

      [ result_text, result_entities ]
    end

    def build_char_to_utf16_map(text)
      map = {}
      utf16_pos = 0
      text.each_char.with_index do |char, idx|
        map[idx] = utf16_pos
        utf16_pos += char.encode("UTF-16LE").bytesize / 2
      end
      map[text.length] = utf16_pos
      map
    end

    def extract_largest_photo_id
      photos = @message["photo"]
      return nil if photos.blank?

      photos.max_by { |p| p["file_size"].to_i }[nil]
    end
  end
end
