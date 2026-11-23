require "rails_helper"

RSpec.describe "User menu" do
  let_it_be(:competition) { create(:competition, :season, :featured, name: "Season Featured") }
  let_it_be(:plain_user) { create(:user) }
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:judge) { create(:user, :judge) }
  let_it_be(:editor) { create(:user, :editor) }
  let_it_be(:admin) { create(:user, :admin) }

  let(:document) { Nokogiri::HTML(response.body) }
  let(:user_area) { document.at_css("#site-top-bar #site-user-area") }
  let(:menu) { document.at_css("#site-user-menu") }
  let(:menu_button) { document.at_css("#site-user-menu-button") }
  let(:role_paths) do
    {
      podcast: podcast_episodes_path,
      protocols: judge_protocols_path,
      breakdowns: judge_breakdowns_path,
      help: help_index_path,
      manage_news: admin_news_index_path,
      telegram: admin_telegram_settings_path,
      admin: avo.root_path,
      notification_settings: edit_notification_settings_path
    }
  end
  let(:expected_hrefs) { role_paths.values_at(*expected_keys) }
  let(:signed_in_user) { nil }

  before do
    sign_in signed_in_user if signed_in_user
    get news_index_path
  end

  shared_examples "the user's role links" do
    it "lists exactly the role links in order" do
      expect(menu.css("a").pluck("href")).to eq(expected_hrefs)
    end

    it "ends with a sign-out form" do
      expect(menu.css("li").last.at_css("form[action='#{destroy_user_session_path}'] input[name='_method']")["value"])
        .to eq("delete")
    end
  end

  context "when signed out" do
    it { expect(menu).to be_nil }
    it { expect(menu_button).to be_nil }
  end

  context "when signed in" do
    let(:signed_in_user) { plain_user }
    let(:expected_keys) { [] }

    it_behaves_like "the user's role links"


    let(:menu_wrapper) { user_area.at_css("[data-controller='menu']") }

    it { expect(user_area.at_css("#site-user-menu")).to be_present }
    it { expect(menu_wrapper["class"]).to include("hidden", "lg:block") }

    it "closes the menu on an outside press, on Escape, on focus leaving it and before Turbo caches the page" do
      expect(menu_wrapper["data-action"].split).to contain_exactly(
        "pointerdown@window->menu#closeOnOutside",
        "keydown.esc@window->menu#close",
        "focusout->menu#closeOnFocusOut",
        "turbo:before-cache@document->menu#close"
      )
    end

    it { expect(menu["class"]).to include("vm-panel", "vm-panel--raised", "hidden") }
    it { expect(menu["data-menu-target"]).to eq("nav") }
    it { expect(menu["aria-label"]).to eq(I18n.t("nav.account_menu")) }
    it { expect(menu_button.text.strip).to eq(I18n.t("nav.account_menu")) }
    it { expect(menu_button["type"]).to eq("button") }
    it { expect(menu_button["aria-controls"]).to eq("site-user-menu") }
    it { expect(menu_button["aria-expanded"]).to eq("false") }
    it { expect(menu_button["data-menu-target"]).to eq("button") }
    it { expect(menu_button["data-action"]).to eq("click->menu#toggle") }
    it { expect(menu.at_css("form button").text.strip).to eq(I18n.t("nav.sign_out")) }
    it { expect(user_area.at_css("a[href='#{new_user_session_path}']")).to be_nil }
  end

  context "when signed in as a subscriber" do
    let(:signed_in_user) { subscriber }
    let(:expected_keys) { %i[podcast] }

    it_behaves_like "the user's role links"
  end

  context "when signed in as an editor" do
    let(:signed_in_user) { editor }
    let(:expected_keys) { %i[manage_news notification_settings] }

    it_behaves_like "the user's role links"
  end

  context "when signed in as a judge" do
    let(:signed_in_user) { judge }

    context "with the game_breakdown toggle on" do
      let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
      let(:expected_keys) { %i[protocols breakdowns help] }

      it_behaves_like "the user's role links"
    end

    context "with the game_breakdown toggle off" do
      let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: false) }
      let(:expected_keys) { %i[protocols help] }

      it_behaves_like "the user's role links"
    end
  end

  context "when signed in as an admin" do
    let(:signed_in_user) { admin }

    context "with the game_breakdown toggle on" do
      let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
      let(:expected_keys) { %i[podcast protocols breakdowns help manage_news telegram admin notification_settings] }

      it_behaves_like "the user's role links"


      it "labels each link" do
        expect(menu.css("a").map { |link| link.text.strip }).to eq(expected_keys.map { |key| I18n.t("nav.#{key}") })
      end
    end

    context "with the game_breakdown toggle off" do
      let(:expected_keys) { %i[podcast protocols help manage_news telegram admin notification_settings] }

      it_behaves_like "the user's role links"
    end
  end
end
