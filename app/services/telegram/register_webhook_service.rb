require "net/http"
require "json"

module Telegram
  class RegisterWebhookService
    Result = Data.define(:success, :description)

    BASE_URL = "https://api.telegram.org"

    def self.call(url:)
      new.call(url: url)
    end

    def self.delete
      new.delete
    end

    def call(url:)
      token = bot_token
      return error("Missing required config: bot_token") if token.blank?
      return error("Missing required parameter: url") if url.blank?

      secret = Rails.application.config.x.telegram.webhook_secret
      params = { "url" => url }
      params["secret_token"] = secret if secret.present?

      post_telegram("bot#{token}/setWebhook", params)
    end

    def delete
      token = bot_token
      return error("Missing required config: bot_token") if token.blank?

      post_telegram("bot#{token}/deleteWebhook", {})
    end

    private

    def bot_token
      Rails.application.config.x.telegram.bot_token
    end

    def post_telegram(path, params)
      uri = URI("#{BASE_URL}/#{path}")
      response = Net::HTTP.post_form(uri, params)
      data = JSON.parse(response.body)

      Result.new(success: data["ok"], description: data["description"])
    rescue StandardError => e
      Result.new(success: false, description: "#{e.class}: #{e.message}")
    end

    def error(message)
      Result.new(success: false, description: message)
    end
  end
end
