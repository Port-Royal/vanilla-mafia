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
      return missing_config_error("bot_token") if token.blank?
      return missing_config_error("url") if url.blank?

      secret = Rails.application.config.x.telegram.webhook_secret
      params = { "url" => url }
      params["secret_token"] = secret if secret.present?

      post_telegram("bot#{token}/setWebhook", params)
    end

    def delete
      token = bot_token
      return missing_config_error("bot_token") if token.blank?

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
      Result.new(success: false, description: e.class.to_s)
    end

    def missing_config_error(field)
      Result.new(success: false, description: "Missing required config: #{field}")
    end
  end
end
