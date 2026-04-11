require "rails_helper"

RSpec.describe CyrillicTransliterator do
  describe ".call" do
    def tr(input)
      described_class.call(input)
    end

    context "lowercase letters" do
      it "transliterates simple letters" do
        expect(tr("абвгд")).to eq("abvgd")
      end

      it "transliterates е and ё" do
        expect(tr("ежё")).to eq("ezhyo")
      end

      it "transliterates ж, з, и, й" do
        expect(tr("жзий")).to eq("zhziy")
      end

      it "transliterates к, л, м, н, о, п" do
        expect(tr("клмноп")).to eq("klmnop")
      end

      it "transliterates р, с, т, у, ф" do
        expect(tr("рстуф")).to eq("rstuf")
      end

      it "transliterates multi-char mappings х, ц, ч, ш, щ" do
        expect(tr("хцчшщ")).to eq("khtschshshch")
      end

      it "erases hard sign ъ and soft sign ь" do
        expect(tr("ъь")).to eq("")
      end

      it "transliterates ы, э, ю, я" do
        expect(tr("ыэюя")).to eq("yeyuya")
      end
    end

    context "uppercase letters" do
      it "transliterates uppercase letters to lowercase latin" do
        expect(tr("ИВАН")).to eq("ivan")
      end

      it "transliterates mixed case" do
        expect(tr("Иван")).to eq("ivan")
      end

      it "transliterates uppercase multi-char mappings" do
        expect(tr("ЩЁ")).to eq("shchyo")
      end
    end

    context "non-Cyrillic passthrough" do
      it "passes Latin letters through unchanged" do
        expect(tr("hello")).to eq("hello")
      end

      it "passes digits through unchanged" do
        expect(tr("12345")).to eq("12345")
      end

      it "passes punctuation through unchanged" do
        expect(tr("a-b_c.d")).to eq("a-b_c.d")
      end

      it "passes whitespace through unchanged" do
        expect(tr("a b c")).to eq("a b c")
      end
    end

    context "mixed input" do
      it "handles Cyrillic and Latin together" do
        expect(tr("Kirill Х")).to eq("kirill kh")
      end

      it "handles Cyrillic with digits" do
        expect(tr("Игрок42")).to eq("igrok42")
      end

      it "handles multi-word Cyrillic with spaces" do
        expect(tr("Иван Петров")).to eq("ivan petrov")
      end
    end

    context "edge cases" do
      it "returns an empty string for empty input" do
        expect(tr("")).to eq("")
      end

      it "handles nil by treating it as empty string" do
        expect(tr(nil)).to eq("")
      end

      it "returns whitespace unchanged" do
        expect(tr("   ")).to eq("   ")
      end
    end
  end
end
