namespace :telegram do
  desc "Register webhook URL with Telegram API (requires WEBHOOK_URL env var)"
  task set_webhook: :environment do
    url = ENV["WEBHOOK_URL"]
    abort "Usage: rake telegram:set_webhook WEBHOOK_URL=https://yourapp.com/webhooks/telegram" if url.blank?

    result = Telegram::RegisterWebhookService.call(url: url)

    if result.success
      puts "Webhook set successfully: #{result.description}"
    else
      abort "Failed to set webhook: #{result.description}"
    end
  end

  desc "Delete webhook registration from Telegram API"
  task delete_webhook: :environment do
    result = Telegram::RegisterWebhookService.delete

    if result.success
      puts "Webhook deleted successfully: #{result.description}"
    else
      abort "Failed to delete webhook: #{result.description}"
    end
  end
end
