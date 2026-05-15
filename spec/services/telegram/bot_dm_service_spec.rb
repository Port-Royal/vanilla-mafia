require "rails_helper"

RSpec.describe Telegram::BotDmService do
  let(:bot_token) { "123456:ABC-DEF" }
  let(:chat_id) { 555 }
  let(:text) { "Hello operator" }

  around do |example|
    original_token = Rails.application.config.x.telegram.bot_token
    Rails.application.config.x.telegram.bot_token = bot_token
    example.run
  ensure
    Rails.application.config.x.telegram.bot_token = original_token
  end

  describe ".call" do
    let(:response_body) { { "ok" => true, "result" => { "message_id" => 1 } } }
    let(:http_response) { instance_double(Net::HTTPOK, body: response_body.to_json) }

    before { allow(Net::HTTP).to receive(:post_form).and_return(http_response) }

    it "posts to sendMessage with chat_id and text" do
      described_class.call(chat_id: chat_id, text: text)
      expect(Net::HTTP).to have_received(:post_form).with(
        URI("https://api.telegram.org/bot#{bot_token}/sendMessage"),
        { "chat_id" => chat_id.to_s, "text" => text, "disable_web_page_preview" => "true" }
      )
    end

    it "returns truthy on API success" do
      expect(described_class.call(chat_id: chat_id, text: text)).to be_truthy
    end

    context "when the API returns ok=false" do
      let(:response_body) { { "ok" => false, "description" => "chat not found" } }

      it "logs a warning and returns false" do
        allow(Rails.logger).to receive(:warn)
        result = described_class.call(chat_id: chat_id, text: text)
        expect(result).to be false
        expect(Rails.logger).to have_received(:warn).with(a_string_matching(/telegram_bot_dm.+chat not found/))
      end
    end

    context "when the network fails" do
      before { allow(Net::HTTP).to receive(:post_form).and_raise(Net::ReadTimeout) }

      it "swallows the error and returns false" do
        allow(Rails.logger).to receive(:warn)
        expect(described_class.call(chat_id: chat_id, text: text)).to be false
        expect(Rails.logger).to have_received(:warn).with(a_string_matching(/Net::ReadTimeout/))
      end
    end

    context "when bot_token is blank" do
      let(:bot_token) { nil }

      it "returns false without calling the API" do
        result = described_class.call(chat_id: chat_id, text: text)
        expect(result).to be false
        expect(Net::HTTP).not_to have_received(:post_form)
      end
    end
  end
end
