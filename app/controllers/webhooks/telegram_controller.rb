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
      provided_token = params[:token].to_s
      expected_token = Rails.application.config.x.telegram.bot_token.to_s
      return false if provided_token.blank? || expected_token.blank?
      return false unless provided_token.length == expected_token.length

      ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
    end

    def payload
      request.request_parameters.except(:token, :controller, :action)
    end
  end
end
