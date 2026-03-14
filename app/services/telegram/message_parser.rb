module Telegram
  class MessageParser
    Result = Data.define(:text, :from_id, :from_username, :from_first_name, :chat_id, :photo_file_ids, :news) do
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
      news = NEWS_TAG_PATTERN.match?(raw_text)
      text = raw_text.gsub(NEWS_TAG_PATTERN, "").squish

      from = @message["from"]

      Result.new(
        text: text,
        from_id: from&.dig("id"),
        from_username: from&.dig("username"),
        from_first_name: from&.dig("first_name"),
        chat_id: @message.dig("chat", "id"),
        photo_file_ids: extract_photo_ids,
        news: news
      )
    end

    private

    def extract_photo_ids
      photos = @message["photo"]
      return [] if photos.nil?

      photos.map { |p| p["file_id"] }
    end
  end
end
