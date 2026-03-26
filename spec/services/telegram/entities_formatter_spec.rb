require "rails_helper"

RSpec.describe Telegram::EntitiesFormatter do
  describe ".call" do
    subject(:html) { described_class.call(text, entities) }

    context "when text has no entities" do
      let(:text) { "Hello world" }
      let(:entities) { [] }

      it "returns HTML-escaped text" do
        expect(html).to eq("Hello world")
      end
    end

    context "when text is blank" do
      let(:text) { "" }
      let(:entities) { [] }

      it "returns empty string" do
        expect(html).to eq("")
      end
    end

    context "when text is nil" do
      let(:text) { nil }
      let(:entities) { [] }

      it "returns empty string" do
        expect(html).to eq("")
      end
    end

    context "when entities is nil" do
      let(:text) { "Hello" }
      let(:entities) { nil }

      it "returns plain text" do
        expect(html).to eq("Hello")
      end
    end

    context "with bold entity" do
      let(:text) { "Hello bold world" }
      let(:entities) { [ { "type" => "bold", "offset" => 6, "length" => 4 } ] }

      it "wraps text in strong tags" do
        expect(html).to eq("Hello <strong>bold</strong> world")
      end
    end

    context "with italic entity" do
      let(:text) { "Hello italic world" }
      let(:entities) { [ { "type" => "italic", "offset" => 6, "length" => 6 } ] }

      it "wraps text in em tags" do
        expect(html).to eq("Hello <em>italic</em> world")
      end
    end

    context "with strikethrough entity" do
      let(:text) { "Hello deleted world" }
      let(:entities) { [ { "type" => "strikethrough", "offset" => 6, "length" => 7 } ] }

      it "wraps text in del tags" do
        expect(html).to eq("Hello <del>deleted</del> world")
      end
    end

    context "with code entity" do
      let(:text) { "Run command now" }
      let(:entities) { [ { "type" => "code", "offset" => 4, "length" => 7 } ] }

      it "wraps text in code tags" do
        expect(html).to eq("Run <code>command</code> now")
      end
    end

    context "with pre entity" do
      let(:text) { "Code:\ndef hello\n  puts ok\nend" }
      let(:entities) { [ { "type" => "pre", "offset" => 6, "length" => 23 } ] }

      it "wraps text in pre tags and preserves newlines inside" do
        expect(html).to eq("Code:<br><pre>def hello\n  puts ok\nend</pre>")
      end
    end

    context "with text_link entity" do
      let(:text) { "Visit our site for details" }
      let(:entities) { [ { "type" => "text_link", "offset" => 10, "length" => 4, "url" => "https://example.com" } ] }

      it "wraps text in anchor tags" do
        expect(html).to eq('Visit our <a href="https://example.com">site</a> for details')
      end
    end

    context "with nested bold and italic" do
      let(:text) { "Hello bold and italic end" }
      let(:entities) do
        [
          { "type" => "bold", "offset" => 6, "length" => 15 },
          { "type" => "italic", "offset" => 15, "length" => 6 }
        ]
      end

      it "produces properly nested HTML" do
        expect(html).to eq("Hello <strong>bold and <em>italic</em></strong> end")
      end
    end

    context "with multiple non-overlapping entities" do
      let(:text) { "bold and italic text" }
      let(:entities) do
        [
          { "type" => "bold", "offset" => 0, "length" => 4 },
          { "type" => "italic", "offset" => 9, "length" => 6 }
        ]
      end

      it "applies both tags" do
        expect(html).to eq("<strong>bold</strong> and <em>italic</em> text")
      end
    end

    context "with HTML special characters in text" do
      let(:text) { "Use <br> & \"quotes\"" }
      let(:entities) { [ { "type" => "bold", "offset" => 4, "length" => 4 } ] }

      it "escapes HTML entities in plain text" do
        expect(html).to eq('Use <strong>&lt;br&gt;</strong> &amp; &quot;quotes&quot;')
      end
    end

    context "with newlines in text" do
      let(:text) { "Line one\nLine two\nLine three" }
      let(:entities) { [] }

      it "converts newlines to br tags" do
        expect(html).to eq("Line one<br>Line two<br>Line three")
      end
    end

    context "with Cyrillic text and bold" do
      let(:text) { "Привет мир" }
      let(:entities) { [ { "type" => "bold", "offset" => 7, "length" => 3 } ] }

      it "handles Cyrillic offsets correctly" do
        expect(html).to eq("Привет <strong>мир</strong>")
      end
    end

    context "with unsupported entity type" do
      let(:text) { "Hello #world" }
      let(:entities) { [ { "type" => "hashtag", "offset" => 6, "length" => 6 } ] }

      it "ignores the unsupported entity" do
        expect(html).to eq("Hello #world")
      end
    end

    context "with text_link containing special characters in URL" do
      let(:text) { "Click here" }
      let(:entities) { [ { "type" => "text_link", "offset" => 0, "length" => 10, "url" => "https://example.com/a&b" } ] }

      it "escapes URL special characters" do
        expect(html).to eq('<a href="https://example.com/a&amp;b">Click here</a>')
      end
    end

    context "with entities starting at the same position" do
      let(:text) { "bold-italic text" }
      let(:entities) do
        [
          { "type" => "bold", "offset" => 0, "length" => 11 },
          { "type" => "italic", "offset" => 0, "length" => 11 }
        ]
      end

      it "nests both tags" do
        expect(html).to eq("<strong><em>bold-italic</em></strong> text")
      end
    end

    context "with mixed supported and unsupported entities" do
      let(:text) { "Hello #tag bold end" }
      let(:entities) do
        [
          { "type" => "hashtag", "offset" => 6, "length" => 4 },
          { "type" => "bold", "offset" => 11, "length" => 4 }
        ]
      end

      it "applies only supported entities" do
        expect(html).to eq("Hello #tag <strong>bold</strong> end")
      end
    end

    context "with newline inside bold but not pre" do
      let(:text) { "Start bold\nline end" }
      let(:entities) { [ { "type" => "bold", "offset" => 6, "length" => 9 } ] }

      it "converts newline to br inside non-pre entities" do
        expect(html).to eq("Start <strong>bold<br>line</strong> end")
      end
    end

    context "with newlines both inside and outside pre" do
      let(:text) { "Before\ndef foo\nend\nAfter" }
      let(:entities) { [ { "type" => "pre", "offset" => 7, "length" => 11 } ] }

      it "converts newlines to br outside pre but preserves inside" do
        expect(html).to eq("Before<br><pre>def foo\nend</pre><br>After")
      end
    end

    context "with leading and trailing whitespace" do
      let(:text) { "  Hello world  " }
      let(:entities) { [] }

      it "strips leading and trailing whitespace" do
        expect(html).to eq("Hello world")
      end
    end
  end
end
