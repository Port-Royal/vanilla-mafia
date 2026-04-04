require "rails_helper"

RSpec.describe Telegram::NewsScorer do
  describe ".call" do
    subject(:score) { described_class.call(parsed_result) }

    let(:parsed_result) do
      Telegram::MessageParser::Result.new(
        text: text,
        html_content: "",
        from_id: 42,
        from_username: "testuser",
        from_first_name: "Denis",
        chat_id: 42,
        photo_file_id: nil,
        raw_text_length: text.length,
        entities: entities
      )
    end

    let(:text) { "Some news article text" }
    let(:entities) { [] }

    context "with no entities" do
      it "returns zero" do
        expect(score).to eq(0)
      end
    end

    context "with formatting entities" do
      let(:entities) do
        [
          { "type" => "bold", "offset" => 0, "length" => 4 },
          { "type" => "italic", "offset" => 5, "length" => 3 }
        ]
      end

      it "adds points per formatting entity" do
        expect(score).to eq(2 * described_class::FORMATTING_POINTS)
      end
    end

    context "with non-formatting entities" do
      let(:entities) do
        [
          { "type" => "mention", "offset" => 0, "length" => 5 },
          { "type" => "hashtag", "offset" => 6, "length" => 4 },
          { "type" => "url", "offset" => 11, "length" => 20 }
        ]
      end

      it "does not score non-formatting entities" do
        expect(score).to eq(0)
      end
    end

    context "with mixed entity types" do
      let(:entities) do
        [
          { "type" => "bold", "offset" => 0, "length" => 4 },
          { "type" => "mention", "offset" => 5, "length" => 5 },
          { "type" => "pre", "offset" => 11, "length" => 10 }
        ]
      end

      it "scores only formatting entities" do
        expect(score).to eq(2 * described_class::FORMATTING_POINTS)
      end
    end

    context "with formatting entities exceeding the cap" do
      let(:entities) do
        20.times.map do |i|
          { "type" => "bold", "offset" => i * 5, "length" => 4 }
        end
      end

      it "caps the formatting score" do
        expect(score).to eq(described_class::FORMATTING_CAP)
      end
    end

    context "with all formatting entity types" do
      let(:entities) do
        %w[bold italic code pre strikethrough].map.with_index do |type, i|
          { "type" => type, "offset" => i * 5, "length" => 4 }
        end
      end

      it "counts all formatting types" do
        expect(score).to eq(5 * described_class::FORMATTING_POINTS)
      end
    end
  end
end
