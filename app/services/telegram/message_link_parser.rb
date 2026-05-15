module Telegram
  class MessageLinkParser
    Result = Data.define(:source_chat, :message_id, :count)

    PRIVATE_LINK = %r{\Ahttps://t\.me/c/(\d+)/(?:\d+/)?(\d+)\z}
    PUBLIC_LINK  = %r{\Ahttps://t\.me/([A-Za-z][A-Za-z0-9_]{3,31})/(\d+)\z}
    SUFFIX       = /\A\s*(.+?)(?:\s+\+(\d+))?\s*\z/

    def self.call(text)
      new(text).call
    end

    def initialize(text)
      @text = text
    end

    def call
      return nil unless @text.is_a?(String)

      match = SUFFIX.match(@text)
      return nil if match.nil?

      link = match[1]
      count = parse_count(match[2])
      return nil if count.nil?

      parse_link(link, count)
    end

    private

    def parse_count(raw)
      return 0 if raw.nil?

      n = Integer(raw, 10)
      return nil if n <= 0

      n
    rescue ArgumentError
      nil
    end

    def parse_link(link, count)
      if (m = PRIVATE_LINK.match(link))
        Result.new(source_chat: -("100#{m[1]}".to_i), message_id: m[2].to_i, count: count)
      elsif (m = PUBLIC_LINK.match(link))
        Result.new(source_chat: "@#{m[1]}", message_id: m[2].to_i, count: count)
      end
    end
  end
end
