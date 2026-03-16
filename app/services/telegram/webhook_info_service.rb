require "net/http"
require "json"

module Telegram
  class WebhookInfoService
    Result = Data.define(:success, :url, :pending_update_count, :description)

    BASE_URL = "https://api.telegram.org"

    def self.call
      new.call
    end

    def call
      token = bot_token
      return error("Missing required config: bot_token") if token.blank?

      uri = URI("#{BASE_URL}/bot#{token}/getWebhookInfo")
      response = Net::HTTP.get_response(uri)
      data = JSON.parse(response.body)

      if data["ok"]
        info = data["result"]
        Result.new(
          success: true,
          url: info["url"],
          pending_update_count: info["pending_update_count"],
          description: nil
        )
      else
        Result.new(success: false, url: nil, pending_update_count: nil, description: data["description"])
      end
    rescue JSON::ParserError,
           SocketError,
           IOError,
           SystemCallError,
           Net::OpenTimeout,
           Net::ReadTimeout => e
      Result.new(success: false, url: nil, pending_update_count: nil, description: "#{e.class}: #{e.message}")
    end

    private

    def bot_token
      Rails.application.config.x.telegram.bot_token
    end

    def error(message)
      Result.new(success: false, url: nil, pending_update_count: nil, description: message)
    end
  end
end
