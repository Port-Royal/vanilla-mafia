require "rails_helper"

RSpec.describe Telegram::WebhookInfoService do
  let(:bot_token) { "123456:ABC-DEF" }

  around do |example|
    original_token = Rails.application.config.x.telegram.bot_token
    Rails.application.config.x.telegram.bot_token = bot_token
    example.run
  ensure
    Rails.application.config.x.telegram.bot_token = original_token
  end

  describe ".call" do
    context "when bot token is blank" do
      let(:bot_token) { nil }

      it "returns unsuccessful result" do
        result = described_class.call
        expect(result.success).to be false
        expect(result.description).to eq("Missing required config: bot_token")
      end
    end

    context "when Telegram API responds with a webhook URL" do
      let(:api_response) do
        { "ok" => true, "result" => { "url" => "https://example.com/webhooks/telegram", "pending_update_count" => 3 } }
      end
      let(:http_response) { instance_double(Net::HTTPOK, body: api_response.to_json) }

      before { allow(Net::HTTP).to receive(:get_response).and_return(http_response) }

      it "returns successful result with url and pending count" do
        result = described_class.call
        expect(result.success).to be true
        expect(result.url).to eq("https://example.com/webhooks/telegram")
        expect(result.pending_update_count).to eq(3)
      end
    end

    context "when webhook URL is empty" do
      let(:api_response) do
        { "ok" => true, "result" => { "url" => "", "pending_update_count" => 0 } }
      end
      let(:http_response) { instance_double(Net::HTTPOK, body: api_response.to_json) }

      before { allow(Net::HTTP).to receive(:get_response).and_return(http_response) }

      it "returns successful result with empty URL" do
        result = described_class.call
        expect(result.success).to be true
        expect(result.url).to eq("")
      end
    end

    context "when Telegram API returns an error" do
      let(:api_response) { { "ok" => false, "description" => "Unauthorized" } }
      let(:http_response) { instance_double(Net::HTTPOK, body: api_response.to_json) }

      before { allow(Net::HTTP).to receive(:get_response).and_return(http_response) }

      it "returns unsuccessful result" do
        result = described_class.call
        expect(result.success).to be false
        expect(result.description).to eq("Unauthorized")
      end
    end

    context "when a network error occurs" do
      before { allow(Net::HTTP).to receive(:get_response).and_raise(SocketError.new("getaddrinfo failed")) }

      it "returns unsuccessful result" do
        result = described_class.call
        expect(result.success).to be false
        expect(result.description).to include("SocketError")
      end
    end

    context "when response JSON is malformed" do
      let(:http_response) { instance_double(Net::HTTPOK, body: "not json") }

      before { allow(Net::HTTP).to receive(:get_response).and_return(http_response) }

      it "returns unsuccessful result" do
        result = described_class.call
        expect(result.success).to be false
        expect(result.description).to include("JSON::ParserError")
      end
    end
  end
end
