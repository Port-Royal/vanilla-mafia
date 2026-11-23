require "rails_helper"

RSpec.describe "Notices" do
  let(:document) { Nokogiri::HTML(response.body) }

  describe "announcement toast" do
    let_it_be(:user) { create(:user) }
    let_it_be(:announcement) { create(:announcement, version: "2.0.0", message_ru: "Обновление тоста", message_en: "Toast update") }

    let(:toast) { document.at_css("[data-controller='announcement-dismiss'].fixed") }
    let(:dismiss_button) { toast.at_css("button[data-action='announcement-dismiss#dismiss']") }
    let(:shell) { document.at_css("body > div.min-h-screen") }

    before do
      sign_in user
      get root_path
    end

    context "with the toast toggle on" do
      let_it_be(:toast_toggle) { create(:feature_toggle, key: "toast_whats_new", enabled: true) }


      let(:title) { toast.at_css("##{toast['aria-labelledby']}") }

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

      it "is announced as a labelled region" do
        expect(toast["role"]).to eq("region")
      end

      it "is labelled by its title" do
        expect(title.text.strip).to eq(I18n.t("home.whats_new.toast_title"))
      end

      it "uses a non-heading title" do
        expect(title.name).to eq("p")
      end

      it { expect(toast.css("h1, h2, h3, h4, h5, h6")).to be_empty }

      it "shows the title in ink semibold" do
        expect(title["class"].split).to include("font-semibold", "text-ink")
      end

      it { expect(dismiss_button["data-announcement-ids"]).to eq(announcement.id.to_s) }
      it { expect(dismiss_button["aria-label"]).to eq(I18n.t("home.whats_new.dismiss")) }

      it "gives the close button a 44 px tap target below lg" do
        expect(dismiss_button["class"].split).to include("min-h-11", "min-w-11", "lg:min-h-0", "lg:min-w-0")
      end

      it "reserves room below the page for the toast until lg" do
        expect(shell["class"].split).to include("pb-40", "lg:pb-0")
      end
    end

    context "with the toast toggle off" do
      it { expect(toast).to be_nil }
      it { expect(shell["class"].split).not_to include("pb-40") }
    end
  end

  describe "flash messages" do
    let_it_be(:user) { create(:user) }

    let(:flash_panels) { document.css("main#site-main .vm-panel[role], main#site-main .bg-emerald-50, main#site-main .bg-red-50") }
    let(:flash_panel) { flash_panels.first }
    let(:failed_sign_in_message) do
      I18n.t("devise.failure.invalid", authentication_keys: User.human_attribute_name(:email).downcase)
    end

    context "with a failed sign-in" do
      before do
        post user_session_path, params: { user: { email: user.email, password: "wrong" } }
        follow_redirect! if response.redirect?
      end


      it { expect(flash_panels.size).to eq(1) }
      it { expect(flash_panel["class"].split).to include("vm-panel", "bg-alert-soft", "text-alert-ink", "border-alert-ink/20") }
      it { expect(flash_panel["role"]).to eq("alert") }
      it { expect(flash_panel.text.strip).to eq(failed_sign_in_message) }
      it { expect(document.css(".bg-red-50")).to be_empty }
    end

    # Signing out leaves its notice in the session; the next page rendered shows it.
    context "with the sign-out notice carried to another signed-out Devise page" do
      before do
        sign_in user
        delete destroy_user_session_path
        get path
      end

      context "when the page is the password reset request" do
        let(:path) { new_user_password_path }

        it { expect(flash_panels.size).to eq(1) }
        it { expect(flash_panel.text.strip).to eq(I18n.t("devise.sessions.signed_out")) }
      end

      context "when the page is the new password form" do
        let(:path) { edit_user_password_path(reset_password_token: "token") }

        it { expect(flash_panels.size).to eq(1) }
        it { expect(flash_panel.text.strip).to eq(I18n.t("devise.sessions.signed_out")) }
      end

      context "when the page is the sign-up form" do
        let(:path) { new_user_registration_path }

        it { expect(flash_panels.size).to eq(1) }
        it { expect(flash_panel.text.strip).to eq(I18n.t("devise.sessions.signed_out")) }
      end
    end

    context "with the sign-in notice carried to the account settings" do
      before do
        post user_session_path, params: { user: { email: user.email, password: user.password } }
        get edit_user_registration_path
      end

      it { expect(flash_panels.size).to eq(1) }
      it { expect(flash_panel.text.strip).to eq(I18n.t("devise.sessions.signed_in")) }
      it { expect(flash_panel["role"]).to eq("status") }
    end

    context "with a notice flash" do
      before do
        sign_in user
        delete destroy_user_session_path
        follow_redirect!
      end

      it { expect(flash_panel.text.strip).to eq(I18n.t("devise.sessions.signed_out")) }
      it { expect(flash_panel["class"].split).to include("text-ink") }
      it { expect(flash_panel["class"]).not_to include("alert") }
      it { expect(flash_panel["role"]).to eq("status") }
    end

    context "with an error flash from a refused protocol" do
      let_it_be(:judge) { create(:user, :judge) }

      let(:participations) do
        (1..10).to_h do |seat|
          [ seat.to_s, { player_name: "", role_code: "", plus: "", minus: "", best_move: "", first_shoot: "0", notes: "", status: "alive" } ]
        end
      end

      before do
        sign_in judge
        post judge_protocols_path, params: { game: { game_number: 1 }, participations: participations }
      end

      it { expect(response).to have_http_status(:unprocessable_content) }
      it { expect(flash_panels.size).to eq(1) }
      it { expect(flash_panel["class"].split).to include("bg-alert-soft", "text-alert-ink", "border-alert-ink/20") }
      it { expect(flash_panel["role"]).to eq("alert") }
    end
  end
end
