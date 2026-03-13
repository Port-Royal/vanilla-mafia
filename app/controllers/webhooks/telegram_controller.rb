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
      params[:token] == Rails.application.config.x.telegram.bot_token
    end

    def payload
      request.request_parameters.except(:token, :controller, :action)
    end
  end
end
