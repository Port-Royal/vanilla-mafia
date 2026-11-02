require "rails_helper"

RSpec.describe "Live protocol focus mode" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:toggle) { create(:feature_toggle, key: "live_protocol", enabled: true) }
  let_it_be(:game) { create(:game) }

  before { sign_in admin }

  context "when on the live protocol" do
    before do
      visit live_judge_protocol_path(game)
      expect(page).to have_css("#lp-work")
    end

    it "hides the site sidebar" do
      expect(page).to have_no_css("#site-sidebar", visible: :all)
    end

    it "hides the mobile header" do
      expect(page).to have_no_css("#site-mobile-header", visible: :all)
    end

    context "when copying the overlay link" do
      before do
        page.execute_script(<<~JS)
          window.copiedText = null
          Object.defineProperty(navigator, "clipboard", { configurable: true, value: { writeText: (text) => { window.copiedText = text; return Promise.resolve() } } })
        JS
        click_button I18n.t("live_protocols.overlay_link.copy")
      end

      it "confirms the copy on the button" do
        expect(page).to have_button(I18n.t("live_protocols.overlay_link.copied"))
      end

      it "puts the overlay URL on the clipboard" do
        expect(page).to have_button(I18n.t("live_protocols.overlay_link.copied"))
        expect(page.evaluate_script("window.copiedText")).to end_with(overlay_game_path(game))
      end

      it "keeps the console keys working while the button has focus" do
        page.driver.browser.action.send_keys("1", "2").perform
        expect(page).to have_css(".lp-picks", text: "1, 2")
      end
    end

    it "keeps a way back to the protocol form and the protocols list" do
      within("#live-protocol-bar") do
        expect(page).to have_link(I18n.t("live_protocols.edit_link"), href: edit_judge_protocol_path(game))
        expect(page).to have_link(I18n.t("live_protocols.list_link"), href: judge_protocols_path)
      end
    end

    context "with the console width measured" do
      let(:console_width) { page.evaluate_script("document.getElementById('live-protocol').getBoundingClientRect().width") }
      let(:window_width) { page.evaluate_script("window.innerWidth") }

      it "spreads the console over the full window width" do
        expect(console_width).to be >= window_width - 48
      end
    end

    it "fits the console in the window height" do
      expect(page.evaluate_script("document.documentElement.scrollHeight <= window.innerHeight")).to be(true)
    end
  end

  context "when on the protocol form" do
    before { visit edit_judge_protocol_path(game) }

    it "shows the site sidebar" do
      expect(page).to have_css("#site-sidebar")
    end
  end
end
