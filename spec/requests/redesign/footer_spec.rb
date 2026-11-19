require "rails_helper"

RSpec.describe "Redesign footer" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:footer) { document.at_css("footer#site-footer") }
  let(:switch_to_old) { document.at_css("#design-switch-to-old") }
  let(:switch_form) { switch_to_old.ancestors("form").first }
  let(:design_cookie) { nil }

  before do
    cookies[:design] = design_cookie if design_cookie
    get hall_path
  end

  context "with the old design" do
    it { expect(footer).to be_nil }
    it { expect(switch_to_old).to be_nil }
  end

  context "with the new design" do
    include_context "with the new design"

    it "follows the main content" do
      expect(document.at_css("main#site-main ~ footer#site-footer")).to be_present
    end

    it "shows the copyright with the current year" do
      expect(footer.text).to include(I18n.t("footer.copyright", year: Date.current.year))
    end

    it { expect(footer.at_css("a[href='#{hall_path}']").text).to eq(I18n.t("nav.hall_of_fame")) }
    it { expect(footer.at_css("a[href='#{news_index_path}']").text).to eq(I18n.t("nav.news")) }
    it { expect(footer.css("nav a").map { |link| link["class"].split }).to all(include("min-h-11")) }
    it { expect(switch_to_old).to be_nil }

    context "when the visitor chose the old design earlier" do
      let(:design_cookie) { "old" }

      it { expect(footer).to be_present }
      it { expect(switch_to_old).to be_nil }
    end

    context "when the visitor chose the new design earlier" do
      let(:design_cookie) { "new" }

      it { expect(footer).to be_present }
      it { expect(switch_to_old).to be_nil }
    end
  end

  context "with the redesign offered" do
    include_context "with the redesign offered"

    context "when the visitor chose the new design" do
      let(:design_cookie) { "new" }

      it { expect(footer).to be_present }
      it { expect(switch_to_old.text.strip).to eq(I18n.t("design.switch_to_old")) }
      it { expect(switch_form["action"]).to eq(design_preference_path) }
      it { expect(switch_form.at_css("input[name='_method']")["value"]).to eq("patch") }
      it { expect(switch_form.at_css("input[name='design']")["value"]).to eq("old") }
      it { expect(switch_to_old["class"].split).to include("min-h-11") }
    end

    context "when the visitor chose the old design" do
      let(:design_cookie) { "old" }

      it { expect(footer).to be_nil }
    end

    context "when the visitor has not chosen" do
      it { expect(footer).to be_nil }
    end
  end
end
