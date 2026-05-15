require "net/http"
require "json"

module Telegram
  class ForwardMessageService
    Result = Data.define(:success, :message, :error_code, :description)

    BASE_URL = "https://api.telegram.org".freeze

    def self.call(from_chat_id:, message_id:, to_chat_id:)
      new.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
    end

    def call(from_chat_id:, message_id:, to_chat_id:)
      token = bot_token
      return error("Missing required config: bot_token") if token.blank?

      params = {
        "chat_id" => to_chat_id.to_s,
        "from_chat_id" => from_chat_id.to_s,
        "message_id" => message_id.to_s,
        "disable_notification" => "true"
      }

      uri = URI("#{BASE_URL}/bot#{token}/forwardMessage")
      response = Net::HTTP.post_form(uri, params)
      data = JSON.parse(response.body)

      if data["ok"]
        Result.new(success: true, message: data["result"], error_code: nil, description: nil)
      else
        Result.new(success: false, message: nil, error_code: data["error_code"], description: data["description"])
      end
    rescue JSON::ParserError,
           SocketError,
           IOError,
           SystemCallError,
           Net::OpenTimeout,
           Net::ReadTimeout => e
      error("#{e.class}: #{e.message}")
    end

    private

    def bot_token
      Rails.application.config.x.telegram.bot_token
    end

    def error(description)
      Result.new(success: false, message: nil, error_code: nil, description: description)
    end
  end
end
