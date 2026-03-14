namespace :telegram do
  desc "Register webhook URL with Telegram API (requires WEBHOOK_URL env var)"
  task set_webhook: :environment do
    url = ENV.fetch("WEBHOOK_URL")
    result = Telegram::RegisterWebhookService.call(url: url)

    if result.success
      puts "Webhook set successfully: #{result.description}"
    else
      puts "Failed to set webhook: #{result.description}"
      exit 1
    end
  end

  desc "Delete webhook registration from Telegram API"
  task delete_webhook: :environment do
    result = Telegram::RegisterWebhookService.delete

    if result.success
      puts "Webhook deleted successfully: #{result.description}"
    else
      puts "Failed to delete webhook: #{result.description}"
      exit 1
    end
  end
end
