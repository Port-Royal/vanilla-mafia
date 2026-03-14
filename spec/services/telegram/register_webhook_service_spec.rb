require "rails_helper"

RSpec.describe Telegram::RegisterWebhookService do
  let(:bot_token) { "123456:ABC-DEF" }
  let(:webhook_secret) { "test-secret-token" }
  let(:webhook_url) { "https://example.com/webhooks/telegram" }
  let(:response_body) { { "ok" => true, "result" => true, "description" => "Webhook was set" } }
  let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

  before do
    Rails.application.config.x.telegram.bot_token = bot_token
    Rails.application.config.x.telegram.webhook_secret = webhook_secret
  end

  describe ".call" do
    context "when Telegram API returns success" do
      before do
        allow(Net::HTTP).to receive(:post_form).and_return(http_response)
      end

      it "returns a successful result" do
        result = described_class.call(url: webhook_url)
        expect(result.success).to be true
      end

      it "includes the description" do
        result = described_class.call(url: webhook_url)
        expect(result.description).to eq("Webhook was set")
      end

      it "calls the correct Telegram API endpoint" do
        described_class.call(url: webhook_url)
        expect(Net::HTTP).to have_received(:post_form)
          .with(URI("https://api.telegram.org/bot#{bot_token}/setWebhook"), hash_including("url" => webhook_url, "secret_token" => webhook_secret))
      end
    end

    context "when Telegram API returns an error" do
      let(:response_body) { { "ok" => false, "description" => "Bad webhook: URL host is empty" } }

      before do
        allow(Net::HTTP).to receive(:post_form).and_return(http_response)
      end

      it "returns a failure result" do
        result = described_class.call(url: webhook_url)
        expect(result.success).to be false
      end

      it "includes the error description" do
        result = described_class.call(url: webhook_url)
        expect(result.description).to eq("Bad webhook: URL host is empty")
      end
    end

    context "when a network error occurs" do
      before do
        allow(Net::HTTP).to receive(:post_form).and_raise(Net::ReadTimeout)
      end

      it "returns a failure result" do
        result = described_class.call(url: webhook_url)
        expect(result.success).to be false
      end

      it "includes the error message" do
        result = described_class.call(url: webhook_url)
        expect(result.description).to include("Net::ReadTimeout")
      end
    end

    context "when webhook_secret is blank" do
      let(:webhook_secret) { nil }

      before do
        allow(Net::HTTP).to receive(:post_form).and_return(http_response)
      end

      it "does not include secret_token in params" do
        described_class.call(url: webhook_url)
        expect(Net::HTTP).to have_received(:post_form)
          .with(anything, { "url" => webhook_url })
      end
    end

    context "when bot_token is blank" do
      let(:bot_token) { nil }

      it "returns a failure result" do
        result = described_class.call(url: webhook_url)
        expect(result.success).to be false
      end

      it "includes an error about missing token" do
        result = described_class.call(url: webhook_url)
        expect(result.description).to include("bot_token")
      end
    end

    context "when url is blank" do
      it "returns a failure result" do
        result = described_class.call(url: "")
        expect(result.success).to be false
      end

      it "includes an error about missing URL" do
        result = described_class.call(url: "")
        expect(result.description).to include("url")
      end
    end
  end

  describe ".delete" do
    context "when Telegram API returns success" do
      let(:response_body) { { "ok" => true, "result" => true, "description" => "Webhook was deleted" } }

      before do
        allow(Net::HTTP).to receive(:post_form).and_return(http_response)
      end

      it "returns a successful result" do
        result = described_class.delete
        expect(result.success).to be true
      end

      it "includes the description" do
        result = described_class.delete
        expect(result.description).to eq("Webhook was deleted")
      end

      it "calls the correct Telegram API endpoint" do
        described_class.delete
        expect(Net::HTTP).to have_received(:post_form)
          .with(URI("https://api.telegram.org/bot#{bot_token}/deleteWebhook"), {})
      end
    end

    context "when bot_token is blank" do
      let(:bot_token) { nil }

      it "returns a failure result" do
        result = described_class.delete
        expect(result.success).to be false
      end
    end
  end
end
