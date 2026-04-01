module Telegram
  class MessageParser
    Result = Data.define(:text, :html_content, :from_id, :from_username, :from_first_name, :chat_id, :photo_file_id)

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

      text = raw_text.squish
      html_content = Telegram::EntitiesFormatter.call(raw_text, raw_entities)

      from = @message["from"]

      Result.new(
        text: text,
        html_content: html_content,
        from_id: from&.dig("id"),
        from_username: from&.dig("username"),
        from_first_name: from&.dig("first_name"),
        chat_id: @message.dig("chat", "id"),
        photo_file_id: extract_largest_photo_id
      )
    end

    private

    def extract_largest_photo_id
      photos = @message["photo"]
      return nil if photos.blank?

      photos.max_by { |p| p["file_size"].to_i }["file_id"]
    end
  end
end
