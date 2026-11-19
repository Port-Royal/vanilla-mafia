require "rails_helper"

RSpec.describe "Design offer" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:offer) { document.at_css("#design-offer") }
  let(:switch_links) { document.css(".design-switch-to-new") }

  let(:offer_shell) { document.at_css("#design-offer-shell") }

  let(:design_cookie) { nil }
  let(:user) { nil }

  before do
    sign_in user if user
    cookies[:design] = design_cookie if design_cookie
    get "/news"
  end

  shared_examples "the layout without the offer shell" do
    it { expect(offer_shell).to be_nil }
    it { expect(document.at_css("body > div.lg\\:flex.lg\\:min-h-screen")).to be_present }
    it { expect(document.at_css("#site-sidebar > div.min-h-screen")).to be_present }
  end

  shared_examples "neither offer nor link" do
    it { expect(offer).to be_nil }
    it { expect(switch_links).to be_empty }

    it_behaves_like "the layout without the offer shell"
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
      it { expect(offer.name).to eq("aside") }
      it { expect(offer["aria-label"]).to eq(I18n.t("design.offer.label")) }

      it "shows visible focus styles on both buttons" do
        expect(offer.css("button.focus-visible\\:outline-ink").size).to eq(2)
      end

      it "wraps the strip and the page in a full-height column" do
        expect(offer_shell["class"].split).to include("flex", "min-h-screen", "flex-col")
      end

      it "puts the strip first in the column" do
        expect(offer_shell.element_children.first).to eq(offer)
      end

      it "lets the page fill the rest of the column" do
        expect(offer_shell.at_css("> div.lg\\:flex.lg\\:flex-1")).to be_present
      end

      it "drops the full-screen height from the page" do
        expect(offer_shell.css(".lg\\:min-h-screen, #site-sidebar .min-h-screen")).to be_empty
      end

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

      it_behaves_like "the layout without the offer shell"

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

      context "when signed in" do
        let_it_be(:signed_in_user) { create(:user) }

        let(:user) { signed_in_user }

        it "shows the link in the sidebar and the mobile nav" do
          expect(switch_links.size).to eq(2)
        end

        it "keeps the sign-out button in the sidebar" do
          expect(document.css("#site-sidebar form[action='#{destroy_user_session_path}']").size).to eq(1)
        end

        it "keeps the sign-out button in the mobile nav" do
          expect(document.css("#mobile-nav form[action='#{destroy_user_session_path}']").size).to eq(1)
        end

        it "places the links in the sidebar and the mobile nav" do
          expect(%w[#site-sidebar #mobile-nav].map { |nav| document.css("#{nav} .design-switch-to-new").size }).to eq([ 1, 1 ])
        end
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
