require "rails_helper"

RSpec.describe GamesHelper do
  describe "#overlay_custom_style" do
    it "returns empty string when no config values set" do
      config = { font_size: nil, color: nil }

      expect(helper.overlay_custom_style(config)).to eq("")
    end

    it "returns font-size when set" do
      config = { font_size: 24, color: nil }

      expect(helper.overlay_custom_style(config)).to eq("font-size: 24px")
    end

    it "returns color when set" do
      config = { font_size: nil, color: "ff0000" }

      expect(helper.overlay_custom_style(config)).to eq("color: #ff0000")
    end

    it "returns both font-size and color when both set" do
      config = { font_size: 16, color: "00ff00" }

      expect(helper.overlay_custom_style(config)).to eq("font-size: 16px; color: #00ff00")
    end
  end
end
