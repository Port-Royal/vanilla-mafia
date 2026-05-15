require "rails_helper"

RSpec.describe Telegram::MessageLinkParser do
  describe ".call" do
    context "with a private supergroup link" do
      it "parses chat_id with the -100 prefix" do
        result = described_class.call("https://t.me/c/1234567890/678")
        expect(result.source_chat).to eq(-1001234567890)
      end

      it "parses message_id" do
        result = described_class.call("https://t.me/c/1234567890/678")
        expect(result.message_id).to eq(678)
      end

      it "defaults count to 0 when no suffix" do
        result = described_class.call("https://t.me/c/1234567890/678")
        expect(result.count).to eq(0)
      end
    end

    context "with a private supergroup topic link" do
      it "uses the last numeric segment as message_id and ignores the topic id" do
        result = described_class.call("https://t.me/c/1234567890/45/678")
        expect(result.message_id).to eq(678)
        expect(result.source_chat).to eq(-1001234567890)
      end
    end

    context "with a public username link" do
      it "returns @username as source_chat" do
        result = described_class.call("https://t.me/channelname/678")
        expect(result.source_chat).to eq("@channelname")
      end

      it "parses message_id" do
        result = described_class.call("https://t.me/channelname/678")
        expect(result.message_id).to eq(678)
      end

      it "carries the range suffix count through to the result" do
        result = described_class.call("https://t.me/channelname/678 +7")
        expect(result.count).to eq(7)
      end
    end

    context "with a range suffix" do
      it "parses +N as count" do
        result = described_class.call("https://t.me/c/1234567890/678 +5")
        expect(result.count).to eq(5)
      end

      it "tolerates extra whitespace" do
        result = described_class.call("  https://t.me/c/1234567890/678   +12  ")
        expect(result.count).to eq(12)
        expect(result.message_id).to eq(678)
      end

      it "interprets the count as base-10 (no octal parsing)" do
        result = described_class.call("https://t.me/c/1234567890/678 +010")
        expect(result.count).to eq(10)
      end

      it "accepts the smallest positive count of +1" do
        result = described_class.call("https://t.me/c/1234567890/678 +1")
        expect(result.count).to eq(1)
      end
    end

    context "with a query string on the link" do
      it "parses a private link with a ?single suffix" do
        result = described_class.call("https://t.me/c/1234567890/678?single")
        expect(result.source_chat).to eq(-1001234567890)
        expect(result.message_id).to eq(678)
      end

      it "parses a public link with a query string" do
        result = described_class.call("https://t.me/channelname/678?comment=42")
        expect(result.source_chat).to eq("@channelname")
        expect(result.message_id).to eq(678)
      end

      it "parses a query-string link with a range suffix" do
        result = described_class.call("https://t.me/c/1234567890/678?single +3")
        expect(result.count).to eq(3)
        expect(result.message_id).to eq(678)
      end
    end

    context "with malformed input" do
      it "returns nil for blank text" do
        expect(described_class.call("")).to be_nil
      end

      it "returns nil for non-telegram URLs" do
        expect(described_class.call("https://example.com/foo/123")).to be_nil
      end

      it "returns nil for telegram link without numeric message id" do
        expect(described_class.call("https://t.me/channelname/abc")).to be_nil
      end

      it "returns nil for /c/ link without message id" do
        expect(described_class.call("https://t.me/c/1234567890")).to be_nil
      end

      it "returns nil for negative or zero count" do
        expect(described_class.call("https://t.me/c/1234567890/678 +0")).to be_nil
        expect(described_class.call("https://t.me/c/1234567890/678 +-1")).to be_nil
      end

      it "returns nil for non-string input" do
        expect(described_class.call(nil)).to be_nil
        expect(described_class.call(12345)).to be_nil
      end
    end
  end
end
