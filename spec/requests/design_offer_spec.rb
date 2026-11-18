require "rails_helper"

RSpec.describe "Design offer" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:offer) { document.at_css("#design-offer") }
  let(:switch_links) { document.css(".design-switch-to-new") }

  let(:design_cookie) { nil }

  before do
    cookies[:design] = design_cookie if design_cookie
    get "/news"
  end

  shared_examples "neither offer nor link" do
    it { expect(offer).to be_nil }
    it { expect(switch_links).to be_empty }
  end

  context "when the toggle was never set" do
    it_behaves_like "neither offer nor link"
  end

  context "when the redesign is offered" do
    include_context "with the redesign offered"

    context "without a design choice" do
      it { expect(offer).to be_present }
      it { expect(offer.text).to include(I18n.t("design.offer.text")) }
      it { expect(switch_links).to be_empty }

      it "posts the new design to the preference path" do
        expect(offer.at_css("form[action='#{design_preference_path}'] input[name='design'][value='new']")).to be_present
      end

      it "posts the old design to the preference path" do
        expect(offer.at_css("form[action='#{design_preference_path}'] input[name='design'][value='old']")).to be_present
      end

      it "uses PATCH for both forms" do
        expect(offer.css("form input[name='_method'][value='patch']").size).to eq(2)
      end

      it "labels the buttons" do
        expect(offer.css("button").map(&:text)).to eq([ I18n.t("design.offer.try"), I18n.t("design.offer.decline") ])
      end
    end

    context "with a garbage design cookie" do
      let(:design_cookie) { "beta" }

      it { expect(offer).to be_present }
    end

    context "when the old design was chosen" do
      let(:design_cookie) { "old" }

      it { expect(offer).to be_nil }

      it "shows the link in the sidebar and the mobile nav" do
        expect(switch_links.size).to eq(2)
      end

      it "places one link in the sidebar" do
        expect(document.css("#site-sidebar .design-switch-to-new").size).to eq(1)
      end

      it "places one link in the mobile nav" do
        expect(document.css("#mobile-nav .design-switch-to-new").size).to eq(1)
      end

      it "posts the new design from each link" do
        expect(switch_links.map { |link| link.at_css("input[name='design']")["value"] }).to eq(%w[new new])
      end

      it "targets the preference path from each link" do
        expect(switch_links.map { |link| link["action"] }).to eq([ design_preference_path ] * 2)
      end

      it "labels each link" do
        expect(switch_links.map { |link| link.at_css("button").text }).to eq([ I18n.t("design.switch_to_new") ] * 2)
      end
    end

    context "when the new design was chosen" do
      let(:design_cookie) { "new" }

      it_behaves_like "neither offer nor link"
    end
  end

  context "when the new design is shown to everyone" do
    include_context "with the new design"

    let(:design_cookie) { "old" }

    it_behaves_like "neither offer nor link"
  end

  context "when the toggle is disabled" do
    let_it_be(:toggle) do
      create(:feature_toggle, key: DesignPreference::TOGGLE_KEY, enabled: false, value: "opt_in")
    end

    let(:design_cookie) { "new" }

    it_behaves_like "neither offer nor link"
  end
end
