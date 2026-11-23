require "rails_helper"

RSpec.describe HelpHelper, type: :helper do
  describe "#help_heading" do
    let(:heading) { Nokogiri::HTML.fragment(helper.help_heading("setup", "Настройка")).at_css("h2") }

    it "renders a section heading with the text" do
      expect(heading.text).to eq("Настройка")
    end

    it "anchors the heading" do
      expect(heading["id"]).to eq("setup")
    end

    it "escapes the text" do
      expect(helper.help_heading("setup", "<b>x</b>")).to include("&lt;b&gt;x&lt;/b&gt;")
    end
  end

  describe "#help_sections" do
    context "when no heading was written" do
      it "is empty" do
        expect(helper.help_sections).to eq([])
      end
    end

    context "when headings were written" do
      before do
        helper.help_heading("setup", "Настройка")
        helper.help_heading("blocks", "Блоки")
      end

      it "records them in order" do
        expect(helper.help_sections).to eq([
          HelpHelper::Section.new("setup", "Настройка"),
          HelpHelper::Section.new("blocks", "Блоки")
        ])
      end
    end
  end

  describe "#help_key_caps" do
    let(:fragment) { Nokogiri::HTML.fragment(helper.help_key_caps(cell)) }
    let(:caps) { fragment.css("kbd").map(&:text) }

    context "with a single key" do
      let(:cell) { "Enter" }

      it { expect(caps).to eq([ "Enter" ]) }
    end

    context "with a list of keys" do
      let(:cell) { "F, G, X" }

      it "gives each key its own cap" do
        expect(caps).to eq(%w[F G X])
      end

      it "keeps the commas between the caps" do
        expect(fragment.text).to eq("F, G, X")
      end
    end

    context "with a list of key combinations" do
      let(:cell) { "Shift+F, Shift+G" }

      it { expect(caps).to eq([ "Shift+F", "Shift+G" ]) }
    end

    context "with a digit key" do
      let(:cell) { "1, 2" }

      it { expect(caps).to eq(%w[1 2]) }
    end

    context "with words rather than keys" do
      let(:cell) { "номера" }

      it "keeps the whole cell in one cap" do
        expect(caps).to eq([ "номера" ])
      end
    end

    context "with a list mixing keys and words" do
      let(:cell) { "номер, Enter" }

      it "keeps the whole cell in one cap" do
        expect(caps).to eq([ "номер, Enter" ])
      end
    end

    context "with a lowercase letter" do
      let(:cell) { "a, b" }

      it "keeps the whole cell in one cap" do
        expect(caps).to eq([ "a, b" ])
      end
    end

    context "with markup in the cell" do
      let(:cell) { "<b>x</b>" }

      it "escapes it" do
        expect(helper.help_key_caps(cell)).to include("&lt;b&gt;x&lt;/b&gt;")
      end
    end
  end
end
