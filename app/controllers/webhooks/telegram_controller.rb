module Webhooks
  class TelegramController < ActionController::API
    def create
      unless valid_token?
        head :unauthorized
        return
      end

      ProcessTelegramWebhookJob.perform_later(payload)
      head :ok
    end

    private

    def valid_token?
      provided_token = request.headers["X-Telegram-Bot-Api-Secret-Token"].to_s
      expected_token = Rails.application.config.x.telegram.bot_token.to_s
      return false if provided_token.blank? || expected_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
    end

    def payload
      request.request_parameters.except(:controller, :action)
    end
  end
end
