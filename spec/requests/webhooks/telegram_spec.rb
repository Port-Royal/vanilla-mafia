require "rails_helper"

RSpec.describe "Webhooks::Telegram" do
  let(:bot_token) { "test-bot-token-123" }
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
    original_token = Rails.application.config.x.telegram.bot_token
    Rails.application.config.x.telegram.bot_token = bot_token
    example.run
  ensure
    Rails.application.config.x.telegram.bot_token = original_token
  end

  def post_webhook(token: bot_token)
    post webhooks_telegram_path,
         params: telegram_payload,
         headers: { "X-Telegram-Bot-Api-Secret-Token" => token },
         as: :json
  end

  describe "POST /webhooks/telegram" do
    context "with valid token" do
      it "returns 200 OK" do
        post_webhook
        expect(response).to have_http_status(:ok)
      end

      it "enqueues a ProcessTelegramWebhookJob" do
        expect { post_webhook }.to have_enqueued_job(ProcessTelegramWebhookJob)
      end
    end

    context "with invalid token" do
      it "returns 401 Unauthorized" do
        post_webhook(token: "wrong-token")
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not enqueue a job" do
        expect { post_webhook(token: "wrong-token") }.not_to have_enqueued_job(ProcessTelegramWebhookJob)
      end
    end

    context "without token header" do
      it "returns 401 Unauthorized" do
        post webhooks_telegram_path, params: telegram_payload, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
