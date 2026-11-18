require "rails_helper"

RSpec.describe "Redesign notices" do
  let(:document) { Nokogiri::HTML(response.body) }

  describe "announcement toast" do
    let_it_be(:user) { create(:user) }
    let_it_be(:announcement) { create(:announcement, version: "2.0.0", message_ru: "Обновление тоста", message_en: "Toast update") }
    let_it_be(:toast_toggle) { create(:feature_toggle, key: "toast_whats_new", enabled: true) }

    let(:toast) { document.at_css("[data-controller='announcement-dismiss'].fixed") }
    let(:dismiss_button) { toast.at_css("button[data-action='announcement-dismiss#dismiss']") }

    before do
      sign_in user
      get root_path
    end

    context "with the old design" do
      it { expect(toast["class"]).to eq("fixed bottom-4 right-4 z-50 max-w-sm") }
      it { expect(toast.at_css(".vm-panel--raised")).to be_nil }
      it { expect(toast.at_css("h4.text-maroon")).to be_present }
    end

    context "with the new design" do
      include_context "with the new design"

      it "spans the phone width minus the gutters and sits bottom right from lg" do
        expect(toast["class"].split).to include("fixed", "bottom-4", "inset-x-4", "lg:left-auto", "lg:right-4", "lg:max-w-sm")
      end

      it "takes the shell focus ring" do
        expect(toast["class"].split).to include("vm-chrome")
      end

      it { expect(toast["data-announcement-dismiss-url-value"]).to eq(announcement_dismissals_path) }
      it { expect(toast.at_css(".vm-panel.vm-panel--raised")).to be_present }
      it { expect(toast.at_css(".vm-panel--raised").text).to include("Обновление тоста") }
      it { expect(toast.to_html).not_to include("maroon") }
      it { expect(document.css("[data-controller='announcement-dismiss'].fixed").size).to eq(1) }

      it "shows the title in ink semibold" do
        expect(toast.at_css(".font-semibold.text-ink").text.strip).to eq(I18n.t("home.whats_new.toast_title"))
      end

      it { expect(dismiss_button["data-announcement-ids"]).to eq(announcement.id.to_s) }
      it { expect(dismiss_button["aria-label"]).to eq(I18n.t("home.whats_new.dismiss")) }

      it "gives the close button a 44 px tap target below lg" do
        expect(dismiss_button["class"].split).to include("min-h-11", "min-w-11", "lg:min-h-0", "lg:min-w-0")
      end
    end
  end

  describe "flash messages" do
    let_it_be(:user) { create(:user) }

    before do
      post user_session_path, params: { user: { email: user.email, password: "wrong" } }
      follow_redirect! if response.redirect?
    end

    context "with the new design" do
      include_context "with the new design"

      let(:flash_panels) { document.css("main#site-main > .vm-panel") }

      it { expect(flash_panels.size).to eq(1) }
      it { expect(flash_panels.first["class"].split).to include("bg-alert-soft", "text-alert-ink", "border-alert-ink/20") }
      it { expect(flash_panels.first.text.strip).to eq(I18n.t("devise.failure.invalid", authentication_keys: User.human_attribute_name(:email).downcase)) }
      it { expect(document.css(".bg-red-50")).to be_empty }
    end

    context "with the old design" do
      it { expect(document.css(".vm-panel")).to be_empty }
      it { expect(document.css(".bg-red-50")).not_to be_empty }
    end
  end

  describe "a notice flash" do
    include_context "with the new design"

    let_it_be(:user) { create(:user) }

    let(:flash_panel) { document.at_css("main#site-main > .vm-panel") }

    before do
      sign_in user
      delete destroy_user_session_path
      follow_redirect!
    end

    it { expect(flash_panel.text.strip).to eq(I18n.t("devise.sessions.signed_out")) }
    it { expect(flash_panel["class"].split).to include("text-ink") }
    it { expect(flash_panel["class"]).not_to include("alert") }
  end
end
