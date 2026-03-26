require "rails_helper"

RSpec.describe Telegram::MessageParser do
  describe ".call" do
    context "with a text message" do
      let(:payload) do
        {
          "update_id" => 123,
          "message" => {
            "message_id" => 1,
            "from" => { "id" => 42, "first_name" => "Denis", "username" => "testuser" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "Hello world"
          }
        }
      end

      it "extracts the message text" do
        result = described_class.call(payload)
        expect(result.text).to eq("Hello world")
      end

      it "extracts the sender user_id" do
        result = described_class.call(payload)
        expect(result.from_id).to eq(42)
      end

      it "extracts the sender username" do
        result = described_class.call(payload)
        expect(result.from_username).to eq("testuser")
      end

      it "extracts the sender first_name" do
        result = described_class.call(payload)
        expect(result.from_first_name).to eq("Denis")
      end

      it "extracts the chat_id" do
        result = described_class.call(payload)
        expect(result.chat_id).to eq(42)
      end

      it "has no photo" do
        result = described_class.call(payload)
        expect(result.photo_file_id).to be_nil
      end

      it "is not a news message" do
        result = described_class.call(payload)
        expect(result).not_to be_news
      end
    end

    context "with a #news hashtag in text" do
      let(:payload) do
        {
          "update_id" => 124,
          "message" => {
            "message_id" => 2,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "Breaking update #news"
          }
        }
      end

      it "detects as a news message" do
        result = described_class.call(payload)
        expect(result).to be_news
      end

      it "strips the #news tag from text" do
        result = described_class.call(payload)
        expect(result.text).to eq("Breaking update")
      end
    end

    context "with a photo message" do
      let(:payload) do
        {
          "update_id" => 125,
          "message" => {
            "message_id" => 3,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "photo" => [
              { "file_id" => "small_id", "file_size" => 1024, "width" => 90, "height" => 90 },
              { "file_id" => "medium_id", "file_size" => 10240, "width" => 320, "height" => 320 },
              { "file_id" => "large_id", "file_size" => 51200, "width" => 800, "height" => 800 }
            ],
            "caption" => "Photo caption #news"
          }
        }
      end

      it "extracts the largest photo file_id" do
        result = described_class.call(payload)
        expect(result.photo_file_id).to eq("large_id")
      end

      it "uses caption as text" do
        result = described_class.call(payload)
        expect(result.text).to eq("Photo caption")
      end

      it "detects #news in caption" do
        result = described_class.call(payload)
        expect(result).to be_news
      end
    end

    context "with an empty photo array" do
      let(:payload) do
        {
          "update_id" => 131,
          "message" => {
            "message_id" => 4,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "photo" => [],
            "caption" => "Empty photo"
          }
        }
      end

      it "returns nil for photo_file_id" do
        result = described_class.call(payload)
        expect(result.photo_file_id).to be_nil
      end
    end

    context "with an edited message" do
      let(:payload) do
        {
          "update_id" => 126,
          "edited_message" => {
            "message_id" => 1,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "Edited text"
          }
        }
      end

      it "extracts text from edited_message" do
        result = described_class.call(payload)
        expect(result.text).to eq("Edited text")
      end

      it "extracts sender from edited_message" do
        result = described_class.call(payload)
        expect(result.from_id).to eq(42)
      end
    end

    context "with no message" do
      let(:payload) { { "update_id" => 127 } }

      it "returns nil" do
        result = described_class.call(payload)
        expect(result).to be_nil
      end
    end

    context "with missing sender" do
      let(:payload) do
        {
          "update_id" => 128,
          "message" => {
            "message_id" => 1,
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "Anonymous"
          }
        }
      end

      it "returns nil for sender fields" do
        result = described_class.call(payload)
        expect(result.from_id).to be_nil
        expect(result.from_username).to be_nil
        expect(result.from_first_name).to be_nil
      end
    end

    context "with multiple #news tags" do
      let(:payload) do
        {
          "update_id" => 130,
          "message" => {
            "message_id" => 1,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "#news Update #news"
          }
        }
      end

      it "strips all #news tags" do
        result = described_class.call(payload)
        expect(result.text).to eq("Update")
      end
    end

    context "with a plain text message for html_content" do
      let(:payload) do
        {
          "update_id" => 200,
          "message" => {
            "message_id" => 20,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "Hello world"
          }
        }
      end

      it "sets html_content to plain text" do
        result = described_class.call(payload)
        expect(result.html_content).to eq("Hello world")
      end
    end

    context "with entities in text" do
      let(:payload) do
        {
          "update_id" => 201,
          "message" => {
            "message_id" => 21,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "#news Bold update here",
            "entities" => [
              { "type" => "hashtag", "offset" => 0, "length" => 5 },
              { "type" => "bold", "offset" => 6, "length" => 4 }
            ]
          }
        }
      end

      it "strips #news and adjusts entity offsets in html_content" do
        result = described_class.call(payload)
        expect(result.html_content).to eq("<strong>Bold</strong> update here")
      end

      it "strips #news from plain text" do
        result = described_class.call(payload)
        expect(result.text).to eq("Bold update here")
      end
    end

    context "with entities in caption" do
      let(:payload) do
        {
          "update_id" => 202,
          "message" => {
            "message_id" => 22,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "photo" => [ { "file_id" => "abc", "file_size" => 1024, "width" => 90, "height" => 90 } ],
            "caption" => "#news Photo caption",
            "caption_entities" => [
              { "type" => "hashtag", "offset" => 0, "length" => 5 },
              { "type" => "italic", "offset" => 6, "length" => 5 }
            ]
          }
        }
      end

      it "applies caption entities to html_content" do
        result = described_class.call(payload)
        expect(result.html_content).to eq("<em>Photo</em> caption")
      end
    end

    context "with newlines in text" do
      let(:payload) do
        {
          "update_id" => 203,
          "message" => {
            "message_id" => 23,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "#news Line one\nLine two"
          }
        }
      end

      it "preserves newlines as br tags in html_content" do
        result = described_class.call(payload)
        expect(result.html_content).to eq("Line one<br>Line two")
      end

      it "squishes newlines in plain text" do
        result = described_class.call(payload)
        expect(result.text).to eq("Line one Line two")
      end
    end

    context "with #news tag case-insensitivity" do
      let(:payload) do
        {
          "update_id" => 129,
          "message" => {
            "message_id" => 1,
            "from" => { "id" => 42, "first_name" => "Denis" },
            "chat" => { "id" => 42, "type" => "private" },
            "date" => 1_700_000_000,
            "text" => "Update #News here"
          }
        }
      end

      it "detects #News as news" do
        result = described_class.call(payload)
        expect(result).to be_news
      end

      it "strips the tag regardless of case" do
        result = described_class.call(payload)
        expect(result.text).to eq("Update here")
      end
    end
  end
end
