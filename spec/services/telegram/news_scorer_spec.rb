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
        raw_text_length: raw_text.length,
        entities: entities,
        raw_text: raw_text
      )
    end

    let(:text) { "Some news article text" }
    let(:raw_text) { text }
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

    context "with paragraph breaks" do
      let(:raw_text) { "First paragraph.\n\nSecond paragraph.\n\nThird paragraph." }

      it "adds points per paragraph break" do
        expect(score).to eq(2 * described_class::PARAGRAPH_POINTS)
      end
    end

    context "with single newlines only" do
      let(:raw_text) { "Line one.\nLine two.\nLine three." }

      it "does not score single newlines" do
        expect(score).to eq(0)
      end
    end

    context "with paragraph breaks exceeding the cap" do
      let(:raw_text) { ([ "Paragraph" ] * 15).join("\n\n") }

      it "caps the paragraph score" do
        expect(score).to eq(described_class::PARAGRAPH_CAP)
      end
    end

    context "with formatting entities and paragraph breaks" do
      let(:raw_text) { "Bold heading\n\nSome body text." }
      let(:entities) do
        [ { "type" => "bold", "offset" => 0, "length" => 12 } ]
      end

      it "sums both signals" do
        expected = described_class::FORMATTING_POINTS + described_class::PARAGRAPH_POINTS
        expect(score).to eq(expected)
      end
    end
  end
end
