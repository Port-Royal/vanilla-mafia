class ProcessTelegramWebhookJob < ApplicationJob
  queue_as :default

  def perform(payload)
    Rails.logger.debug { "Processing Telegram webhook update_id=#{payload['update_id']}" }
  end
end
