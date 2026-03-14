module Webhooks
  class TelegramController < ActionController::API
    def create
      unless valid_secret?
        head :unauthorized
        return
      end

      ProcessTelegramWebhookJob.perform_later(payload)
      head :ok
    end

    private

    def valid_secret?
      provided = request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s
      expected = Rails.application.config.x.telegram.webhook_secret.to_s
      return false if provided.blank? || expected.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided, expected)
    end

    def payload
      request.request_parameters
    end
  end
end
