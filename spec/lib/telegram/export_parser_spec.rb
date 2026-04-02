require "rails_helper"
require_relative "../../../lib/telegram/export_parser"

RSpec.describe Telegram::ExportParser do
  let(:export_dir) { Rails.root.join("tmp", "telegram_export_test") }
  let(:from_id) { "user123456" }
  let(:parser) { described_class.new(export_dir, from_id: from_id) }

  before do
    FileUtils.mkdir_p(export_dir)
  end

  after do
    FileUtils.rm_rf(export_dir)
  end

  describe "#call" do
    context "when export contains matching messages" do
      let(:long_text) { "A" * 600 }

      before do
        write_export([
          message(from_id: from_id, text: long_text),
          message(from_id: from_id, text: "short"),
          message(from_id: "user999", text: long_text)
        ])
      end

      it "filters by from_id and minimum text length" do
        results = parser.call

        expect(results.size).to eq(1)
        expect(results.first.plain_text).to eq(long_text)
      end
    end

    context "when message has formatted text as array" do
      let(:formatted_text) do
        [
          "Start of a very long message that continues for a while. ",
          { "type" => "bold", "text" => "Bold section" },
          " and then more plain text follows. " + ("x" * 500)
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "extracts plain text from array parts" do
        results = parser.call
        expected = "Start of a very long message that continues for a while. Bold section and then more plain text follows. " + ("x" * 500)

        expect(results.first.plain_text).to eq(expected)
      end

      it "builds HTML with formatting tags" do
        results = parser.call
        expected = "Start of a very long message that continues for a while. <strong>Bold section</strong> and then more plain text follows. " + ("x" * 500)

        expect(results.first.html_content).to eq(expected)
      end
    end

    context "when message has italic and strikethrough formatting" do
      let(:formatted_text) do
        [
          ("x" * 500) + " ",
          { "type" => "italic", "text" => "italic part" },
          " ",
          { "type" => "strikethrough", "text" => "deleted" }
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "wraps italic with em tags" do
        results = parser.call

        expect(results.first.html_content).to include("<em>italic part</em>")
      end

      it "wraps strikethrough with del tags" do
        results = parser.call

        expect(results.first.html_content).to include("<del>deleted</del>")
      end
    end

    context "when message has a text_link" do
      let(:formatted_text) do
        [
          ("x" * 500) + " ",
          { "type" => "text_link", "text" => "click here", "href" => "https://example.com" }
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "creates an anchor tag with href" do
        results = parser.call

        expect(results.first.html_content).to include('<a href="https://example.com">click here</a>')
      end
    end

    context "when message has underline formatting" do
      let(:formatted_text) do
        [
          ("x" * 500) + " ",
          { "type" => "underline", "text" => "underlined" }
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "wraps with u tags" do
        results = parser.call

        expect(results.first.html_content).to include("<u>underlined</u>")
      end
    end

    context "when message has code and pre formatting" do
      let(:formatted_text) do
        [
          ("x" * 500) + " ",
          { "type" => "code", "text" => "inline_code" },
          " ",
          { "type" => "pre", "text" => "block_code" }
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "wraps code and pre tags" do
        results = parser.call

        expect(results.first.html_content).to include("<code>inline_code</code>")
        expect(results.first.html_content).to include("<pre>block_code</pre>")
      end
    end

    context "when message has unknown entity type" do
      let(:formatted_text) do
        [
          ("x" * 500) + " ",
          { "type" => "mention", "text" => "@someone" }
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "renders the text without wrapping tags" do
        results = parser.call

        expect(results.first.html_content).to include("@someone")
        expect(results.first.html_content).not_to include("<mention>")
      end
    end

    context "when message has a photo" do
      let(:long_text) { "B" * 600 }

      before do
        write_export([
          message(from_id: from_id, text: long_text, photo: "photos/photo_1.jpg")
        ])
      end

      it "stores the photo path" do
        results = parser.call

        expect(results.first.photo).to eq("photos/photo_1.jpg")
      end

      it "does not include photo placeholder in html_content" do
        results = parser.call

        expect(results.first.html_content).not_to include("[PHOTO:")
        expect(results.first.html_content).to eq("B" * 600)
      end
    end

    context "when message has no photo" do
      let(:long_text) { "C" * 600 }

      before do
        write_export([ message(from_id: from_id, text: long_text) ])
      end

      it "returns nil for photo" do
        results = parser.call

        expect(results.first.photo).to be_nil
      end
    end

    context "when text contains newlines" do
      let(:text_with_newlines) { "First paragraph.\n\nSecond paragraph.\n" + ("x" * 500) }

      before do
        write_export([ message(from_id: from_id, text: text_with_newlines) ])
      end

      it "converts newlines to br tags in HTML" do
        results = parser.call

        expect(results.first.html_content).to include("First paragraph.<br><br>Second paragraph.<br>")
      end
    end

    context "when text contains HTML special characters" do
      let(:text_with_html) { "<script>alert('xss')</script> & more " + ("x" * 500) }

      before do
        write_export([ message(from_id: from_id, text: text_with_html) ])
      end

      it "escapes HTML entities" do
        results = parser.call

        expect(results.first.html_content).to include("&lt;script&gt;")
        expect(results.first.html_content).to include("&amp; more")
        expect(results.first.html_content).not_to include("<script>")
      end
    end

    context "when message type is not 'message'" do
      before do
        write_export([
          { "type" => "service", "from_id" => from_id, "text" => "x" * 600, "date" => "2024-01-01T00:00:00" }
        ])
      end

      it "excludes non-message types" do
        expect(parser.call).to be_empty
      end
    end

    context "when message text is blank" do
      before do
        write_export([ message(from_id: from_id, text: "") ])
      end

      it "excludes messages with blank text" do
        expect(parser.call).to be_empty
      end
    end

    context "when export has no matching messages" do
      before do
        write_export([ message(from_id: "user999", text: "x" * 600) ])
      end

      it "returns empty array" do
        expect(parser.call).to be_empty
      end
    end

    context "when message date is preserved" do
      let(:long_text) { "D" * 600 }

      before do
        write_export([ message(from_id: from_id, text: long_text, date: "2023-05-15T14:30:00") ])
      end

      it "includes the message date" do
        results = parser.call

        expect(results.first.date).to eq("2023-05-15T14:30:00")
      end
    end

    context "when formatted text array has newlines in string parts" do
      let(:formatted_text) do
        [
          "First line\nSecond line " + ("x" * 500)
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "converts newlines to br in string parts" do
        results = parser.call

        expect(results.first.html_content).to include("First line<br>Second line")
      end
    end

    context "when formatted text array has HTML entities in entity parts" do
      let(:formatted_text) do
        [
          ("x" * 500) + " ",
          { "type" => "bold", "text" => "Tom & Jerry <3" }
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "escapes HTML in entity text" do
        results = parser.call

        expect(results.first.html_content).to include("<strong>Tom &amp; Jerry &lt;3</strong>")
      end
    end

    context "when text_link has special characters in href" do
      let(:formatted_text) do
        [
          ("x" * 500) + " ",
          { "type" => "text_link", "text" => "link", "href" => "https://example.com?a=1&b=2" }
        ]
      end

      before do
        write_export([ message(from_id: from_id, text: formatted_text) ])
      end

      it "escapes href attribute" do
        results = parser.call

        expect(results.first.html_content).to include("https://example.com?a=1&amp;b=2")
      end
    end

    context "when message has multiple messages from different authors" do
      let(:long_text_a) { "Author A says: " + ("a" * 600) }
      let(:long_text_b) { "Author B says: " + ("b" * 600) }

      before do
        write_export([
          message(from_id: from_id, text: long_text_a),
          message(from_id: "user999", text: long_text_b),
          message(from_id: from_id, text: long_text_b)
        ])
      end

      it "returns only messages from the specified author" do
        results = parser.call

        expect(results.size).to eq(2)
        expect(results.map(&:plain_text)).to all(satisfy { |t| t.length >= 500 })
      end
    end

    context "when message text is exactly at minimum length" do
      let(:exact_text) { "x" * 500 }

      before do
        write_export([ message(from_id: from_id, text: exact_text) ])
      end

      it "includes messages at exactly the minimum length" do
        results = parser.call

        expect(results.size).to eq(1)
      end
    end

    context "when message text is one character below minimum" do
      let(:short_text) { "x" * 499 }

      before do
        write_export([ message(from_id: from_id, text: short_text) ])
      end

      it "excludes messages below minimum length" do
        expect(parser.call).to be_empty
      end
    end

    context "when photo message also has long text" do
      let(:long_text) { "E" * 600 }

      before do
        write_export([
          message(from_id: from_id, text: long_text, photo: "photos/img.jpg")
        ])
      end

      it "keeps html_content without photo placeholder" do
        results = parser.call

        expect(results.first.html_content).to eq("E" * 600)
        expect(results.first.photo).to eq("photos/img.jpg")
      end
    end

    context "when plain text string message has exact content" do
      let(:long_text) { "Hello world! " + ("z" * 500) }

      before do
        write_export([ message(from_id: from_id, text: long_text) ])
      end

      it "returns exact plain text" do
        results = parser.call

        expect(results.first.plain_text).to eq(long_text)
      end

      it "returns HTML with escaped content" do
        results = parser.call

        expect(results.first.html_content).to eq(ERB::Util.html_escape(long_text).gsub("\n", "<br>"))
      end
    end
  end

  private

  def message(from_id:, text:, photo: nil, date: "2024-01-01T12:00:00")
    msg = {
      "type" => "message",
      "from_id" => from_id,
      "text" => text,
      "date" => date
    }
    msg["photo"] = photo if photo
    msg
  end

  def write_export(messages)
    data = { "name" => "Test Chat", "type" => "private_supergroup", "messages" => messages }
    File.write(export_dir.join("result.json"), JSON.generate(data))
  end
end
