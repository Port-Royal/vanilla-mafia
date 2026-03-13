class ProcessTelegramWebhookJob < ApplicationJob
  queue_as :default

  def perform(payload)
    Rails.logger.info("Received Telegram webhook: #{payload.inspect}")
  end
end
