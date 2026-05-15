require "rails_helper"

RSpec.describe Telegram::ForwardMessageService do
  let(:bot_token) { "123456:ABC-DEF" }
  let(:from_chat_id) { -1001234567890 }
  let(:message_id) { 678 }
  let(:to_chat_id) { 555 }

  around do |example|
    original_token = Rails.application.config.x.telegram.bot_token
    Rails.application.config.x.telegram.bot_token = bot_token
    example.run
  ensure
    Rails.application.config.x.telegram.bot_token = original_token
  end

  describe ".call" do
    context "when the API returns ok=true" do
      let(:response_body) do
        {
          "ok" => true,
          "result" => {
            "message_id" => 999,
            "text" => "hello world",
            "from" => { "id" => 42, "is_bot" => true },
            "forward_origin" => {
              "type" => "user",
              "sender_user" => { "id" => 12345, "first_name" => "Alex" },
              "date" => 1710000000
            }
          }
        }
      end
      let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

      before { allow(Net::HTTP).to receive(:post_form).and_return(http_response) }

      it "returns success" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be true
      end

      it "returns the forwarded message hash" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.message).to eq(response_body["result"])
      end

      it "calls the correct API endpoint with correct params" do
        described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(Net::HTTP).to have_received(:post_form).with(
          URI("https://api.telegram.org/bot#{bot_token}/forwardMessage"),
          {
            "chat_id" => to_chat_id.to_s,
            "from_chat_id" => from_chat_id.to_s,
            "message_id" => message_id.to_s,
            "disable_notification" => "true"
          }
        )
      end

      it "accepts @username as from_chat_id" do
        described_class.call(from_chat_id: "@channelname", message_id: message_id, to_chat_id: to_chat_id)
        expect(Net::HTTP).to have_received(:post_form).with(
          anything,
          hash_including("from_chat_id" => "@channelname")
        )
      end
    end

    context "when the API returns ok=false with 400" do
      let(:response_body) { { "ok" => false, "error_code" => 400, "description" => "Bad Request: message to forward not found" } }
      let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

      before { allow(Net::HTTP).to receive(:post_form).and_return(http_response) }

      it "returns failure" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be false
      end

      it "exposes the error_code" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.error_code).to eq(400)
      end

      it "exposes the description" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.description).to eq("Bad Request: message to forward not found")
      end
    end

    context "when the API returns 403" do
      let(:response_body) { { "ok" => false, "error_code" => 403, "description" => "Forbidden: bot is not a member" } }
      let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

      before { allow(Net::HTTP).to receive(:post_form).and_return(http_response) }

      it "returns failure with error_code 403" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be false
        expect(result.error_code).to eq(403)
      end
    end

    context "when bot_token is blank" do
      let(:bot_token) { nil }

      it "returns failure with a missing-token description" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be false
        expect(result.description).to include("bot_token")
      end
    end

    context "when a network error occurs" do
      before { allow(Net::HTTP).to receive(:post_form).and_raise(Net::ReadTimeout) }

      it "returns failure with the error class in description" do
        result = described_class.call(from_chat_id: from_chat_id, message_id: message_id, to_chat_id: to_chat_id)
        expect(result.success).to be false
        expect(result.description).to include("Net::ReadTimeout")
      end
    end
  end
end
