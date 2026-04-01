module Telegram
  class ExportParser
    MIN_TEXT_LENGTH = 500

    Message = Data.define(:date, :plain_text, :html_content, :photo)

    def initialize(export_path, from_id:)
      @export_path = Pathname.new(export_path)
      @from_id = from_id
    end

    def call
      data = JSON.parse(@export_path.join("result.json").read)
      messages = data.fetch("messages", [])

      messages
        .select { |m| m["type"] == "message" && m["from_id"] == @from_id }
        .filter_map { |m| parse_message(m) }
        .select { |m| m.plain_text.length >= MIN_TEXT_LENGTH }
    end

    private

    def parse_message(message)
      raw_text = message["text"]
      return nil if raw_text.blank?

      plain_text = extract_plain_text(raw_text)
      html_content = build_html(raw_text)
      photo = message["photo"]

      if photo.present?
        html_content = "[PHOTO: #{photo}]\n\n#{html_content}"
      end

      Message.new(
        date: message["date"],
        plain_text: plain_text,
        html_content: html_content,
        photo: photo
      )
    end

    def extract_plain_text(text)
      case text
      when String
        text
      when Array
        text.map { |part| part.is_a?(String) ? part : part["text"].to_s }.join
      else
        ""
      end
    end

    def build_html(text)
      case text
      when String
        escape(text).gsub("\n", "<br>")
      when Array
        text.map { |part| format_part(part) }.join
      else
        ""
      end
    end

    def format_part(part)
      if part.is_a?(String)
        escape(part).gsub("\n", "<br>")
      else
        inner = escape(part["text"].to_s).gsub("\n", "<br>")
        wrap_with_tag(inner, part)
      end
    end

    TAG_MAP = {
      "bold" => "strong",
      "italic" => "em",
      "strikethrough" => "del",
      "underline" => "u",
      "code" => "code",
      "pre" => "pre"
    }.freeze

    def wrap_with_tag(inner, part)
      type = part["type"]

      case type
      when "text_link"
        href = escape(part["href"].to_s)
        "<a href=\"#{href}\">#{inner}</a>"
      when *TAG_MAP.keys
        tag = TAG_MAP[type]
        "<#{tag}>#{inner}</#{tag}>"
      else
        inner
      end
    end

    def escape(text)
      ERB::Util.html_escape(text)
    end
  end
end
