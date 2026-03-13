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

  before do
    Rails.application.config.x.telegram.bot_token = bot_token
  end

  describe "POST /webhooks/telegram/:token" do
    context "with valid token" do
      it "returns 200 OK" do
        post webhooks_telegram_path(token: bot_token), params: telegram_payload, as: :json
        expect(response).to have_http_status(:ok)
      end

      it "enqueues a ProcessTelegramWebhookJob" do
        expect {
          post webhooks_telegram_path(token: bot_token), params: telegram_payload, as: :json
        }.to have_enqueued_job(ProcessTelegramWebhookJob)
      end
    end

    context "with invalid token" do
      it "returns 401 Unauthorized" do
        post webhooks_telegram_path(token: "wrong-token"), params: telegram_payload, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not enqueue a job" do
        expect {
          post webhooks_telegram_path(token: "wrong-token"), params: telegram_payload, as: :json
        }.not_to have_enqueued_job(ProcessTelegramWebhookJob)
      end
    end
  end
end
