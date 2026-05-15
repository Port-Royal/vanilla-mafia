require "net/http"
require "json"

module Telegram
  class BotDmService
    BASE_URL = "https://api.telegram.org".freeze

    def self.call(chat_id:, text:)
      new.call(chat_id: chat_id, text: text)
    end

    def call(chat_id:, text:)
      token = Rails.application.config.x.telegram.bot_token
      return false if token.blank?

      uri = URI("#{BASE_URL}/bot#{token}/sendMessage")
      response = Net::HTTP.post_form(uri, {
        "chat_id" => chat_id.to_s,
        "text" => text,
        "disable_web_page_preview" => "true"
      })
      data = JSON.parse(response.body)

      return true if data["ok"]

      log_failure("api error: #{data["description"]}")
      false
    rescue JSON::ParserError,
           SocketError,
           IOError,
           SystemCallError,
           Net::OpenTimeout,
           Net::ReadTimeout => e
      log_failure("#{e.class}: #{e.message}")
      false
    end

    private

    def log_failure(detail)
      Rails.logger.warn({ event: "telegram_bot_dm.failed", detail: detail }.to_json)
    end
  end
end
