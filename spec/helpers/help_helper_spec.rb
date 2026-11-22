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
end
