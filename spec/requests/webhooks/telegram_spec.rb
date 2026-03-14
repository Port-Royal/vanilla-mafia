require "rails_helper"

RSpec.describe "Webhooks::Telegram" do
  let(:webhook_secret) { "test-webhook-secret-123" }
  let(:telegram_payload) do
    {
      update_id: 123456,
      message: {
        message_id: 1,
        from: { id: 42, first_name: "Test" },
        chat: { id: 42, type: "private" },
        text: "Hello"
      }
    }
  end

  around do |example|
    original_secret = Rails.application.config.x.telegram.webhook_secret
    Rails.application.config.x.telegram.webhook_secret = webhook_secret
    example.run
  ensure
    Rails.application.config.x.telegram.webhook_secret = original_secret
  end

  def post_webhook(secret: webhook_secret)
    post webhooks_telegram_path,
         params: telegram_payload,
         headers: { "X-Telegram-Bot-Api-Secret-Token" => secret },
         as: :json
  end

  describe "POST /webhooks/telegram" do
    context "with valid secret" do
      it "returns 200 OK" do
        post_webhook
        expect(response).to have_http_status(:ok)
      end

      it "enqueues a ProcessTelegramWebhookJob" do
        expect { post_webhook }.to have_enqueued_job(ProcessTelegramWebhookJob)
      end
    end

    context "with invalid secret" do
      it "returns 401 Unauthorized" do
        post_webhook(secret: "wrong-secret")
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not enqueue a job" do
        expect { post_webhook(secret: "wrong-secret") }.not_to have_enqueued_job(ProcessTelegramWebhookJob)
      end
    end

    context "without secret header" do
      it "returns 401 Unauthorized" do
        post webhooks_telegram_path, params: telegram_payload, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
