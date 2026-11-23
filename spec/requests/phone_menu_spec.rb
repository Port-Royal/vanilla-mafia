require "rails_helper"

RSpec.describe "Phone menu" do
  let_it_be(:competition) { create(:competition, :season, :featured, name: "Season Featured") }
  let_it_be(:plain_user) { create(:user) }
  let_it_be(:subscriber) { create(:user, :subscriber) }
  let_it_be(:judge) { create(:user, :judge) }
  let_it_be(:editor) { create(:user, :editor) }
  let_it_be(:admin) { create(:user, :admin) }

  let(:document) { Nokogiri::HTML(response.body) }
  let(:top_bar) { document.at_css("#site-top-bar") }
  let(:menu) { document.at_css("#site-phone-menu") }
  let(:menu_button) { document.at_css("#site-phone-menu-button") }
  let(:menu_wrapper) { menu_button.ancestors("[data-controller='menu']").first }
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
  let(:public_hrefs) { [ competition_path(slug: competition.slug), hall_path, news_index_path, stats_path ] }
  let(:role_hrefs) { role_paths.values_at(*expected_keys) }
  let(:locale_target) { locale_path(locale: :en) }
  let(:menu_targets) do
    menu.css("a, form").map { |node| node.name == "a" ? node["href"] : node["action"] }
  end
  let(:section_targets) do
    menu.css("ul > li.border-t.border-line").map do |item|
      link = item.at_css("a")
      link ? link["href"] : item.at_css("form")["action"]
    end
  end
  let(:path) { news_index_path }
  let(:signed_in_user) { nil }

  before do
    sign_in signed_in_user if signed_in_user
    get path
  end


  shared_examples "the phone menu links" do
    it "lists public links, role links, sign out and the locale switch in order" do
      expect(menu_targets).to eq(public_hrefs + role_hrefs + [ destroy_user_session_path, locale_target ])
    end

    it "signs out with DELETE" do
      expect(menu.at_css("form[action='#{destroy_user_session_path}'] input[name='_method']")["value"])
        .to eq("delete")
    end

    it { expect(menu.at_css("a[href='#{new_user_session_path}']")).to be_nil }
  end

  describe "the button" do
    it { expect(menu_button["type"]).to eq("button") }
    it { expect(menu_button["aria-controls"]).to eq("site-phone-menu") }
    it { expect(menu_button["aria-expanded"]).to eq("false") }
    it { expect(menu_button["aria-label"]).to eq(I18n.t("nav.menu")) }
    it { expect(menu_button["data-menu-target"]).to eq("button") }
    it { expect(menu_button["data-action"]).to eq("click->menu#toggle") }
    it { expect(menu_button["class"]).to include("min-h-11", "min-w-11") }
    it { expect(menu_button.at_css("svg[aria-hidden='true']")).to be_present }
  end

  describe "the controller element" do
    it { expect(top_bar.at_css("#site-phone-menu-button")).to be_present }
    it { expect(menu_wrapper["class"]).to include("lg:hidden") }
    it { expect(menu_wrapper.at_css("#site-phone-menu")).to be_present }
    it { expect(menu_wrapper.at_css("#site-user-menu")).to be_nil }

    it "closes the menu on an outside pointer, Escape, focus leaving it and before Turbo caches the page" do
      expect(menu_wrapper["data-action"].split)
        .to contain_exactly(
          "pointerdown@window->menu#closeOnOutside",
          "keydown.esc@window->menu#close",
          "focusout->menu#closeOnFocusOut",
          "turbo:before-cache@document->menu#close"
        )
    end
  end

  describe "the panel" do
    it { expect(menu.name).to eq("nav") }
    it { expect(menu["aria-label"]).to eq(I18n.t("nav.menu")) }
    it { expect(menu["data-menu-target"]).to eq("nav") }
    it { expect(menu["class"]).to include("hidden", "lg:hidden", "absolute", "inset-x-0", "top-full") }
    it { expect(top_bar["class"]).to include("relative") }

    it { expect(menu["class"]).to include("z-[60]") }
    it { expect(menu["class"]).to include("max-h-[calc(100dvh-3.5rem)]", "overflow-y-auto") }

    it "gives every link and button a 44 px tap target" do
      expect(menu.css("a, button").map { |target| target["class"] }).to all(include("min-h-11"))
    end
  end

  describe "the locale row" do
    let(:locale_row) { menu.css("ul > li").last }
    let(:locale_button) { locale_row.at_css("form[action='#{locale_target}'] button") }

    it { expect(locale_row["class"]).to include("pl-3") }
    it { expect(locale_button["class"]).to include("inline-flex", "min-h-11", "min-w-11", "items-center", "justify-center") }
    it { expect(locale_button["lang"]).to eq("en") }
  end

  describe "the desktop controls" do
    let(:desktop_controls) { top_bar.at_css("#site-user-area").parent }

    it { expect(desktop_controls["class"]).to include("hidden", "lg:flex") }
    it { expect(desktop_controls.at_css(".vm-locale-current")).to be_present }
  end

  context "when signed out" do
    it "lists public links, sign in and the locale switch in order" do
      expect(menu_targets).to eq(public_hrefs + [ new_user_session_path, locale_target ])
    end

    it { expect(menu.at_css("a[href='#{new_user_session_path}']").text.strip).to eq(I18n.t("nav.sign_in")) }
    it { expect(menu.at_css("a[href='#{new_user_session_path}']")["class"]).to include("pl-3") }
    it { expect(menu.at_css(".vm-locale-current").text).to eq("RU") }
    it { expect(menu.css("ul > li.border-t.border-line").size).to eq(2) }
  end

  context "when signed in" do
    let(:signed_in_user) { plain_user }
    let(:expected_keys) { [] }

    it_behaves_like "the phone menu links"

    it { expect(menu.at_css("form[action='#{destroy_user_session_path}'] button").text.strip).to eq(I18n.t("nav.sign_out")) }
    it { expect(menu.at_css("form[action='#{destroy_user_session_path}'] button")["class"]).to include("pl-3") }
    it { expect(menu.css("ul > li.border-t.border-line").size).to eq(2) }
  end

  context "when signed in as a subscriber" do
    let(:signed_in_user) { subscriber }
    let(:expected_keys) { %i[podcast] }

    it_behaves_like "the phone menu links"

    it "separates public, role, account and locale sections with a line" do
      expect(section_targets).to eq([ podcast_episodes_path, destroy_user_session_path, locale_target ])
    end
  end

  context "when signed in as an editor" do
    let(:signed_in_user) { editor }
    let(:expected_keys) { %i[manage_news notification_settings] }

    it_behaves_like "the phone menu links"
  end

  context "when signed in as a judge" do
    let(:signed_in_user) { judge }

    context "with the game_breakdown toggle on" do
      let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
      let(:expected_keys) { %i[protocols breakdowns help] }

      it_behaves_like "the phone menu links"
    end

    context "with the game_breakdown toggle off" do
      let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: false) }
      let(:expected_keys) { %i[protocols help] }

      it_behaves_like "the phone menu links"
    end
  end

  context "when signed in as an admin" do
    let(:signed_in_user) { admin }

    context "with the game_breakdown toggle on" do
      let_it_be(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
      let(:expected_keys) { %i[podcast protocols breakdowns help manage_news telegram admin notification_settings] }

      it_behaves_like "the phone menu links"

      it "labels each role link" do
        expect(menu.css("a").drop(public_hrefs.size).map { |link| link.text.strip })
          .to eq(expected_keys.map { |key| I18n.t("nav.#{key}") })
      end
    end

    context "with the game_breakdown toggle off" do
      let(:expected_keys) { %i[podcast protocols help manage_news telegram admin notification_settings] }

      it_behaves_like "the phone menu links"
    end
  end

  describe "active item" do
    let(:hall_link) { menu.at_css("a[href='#{hall_path}']") }
    let(:news_link) { menu.at_css("a[href='#{news_index_path}']") }

    context "when on the Hall of Fame page" do
      let(:path) { hall_path }

      it { expect(hall_link["aria-current"]).to eq("page") }
      it { expect(hall_link["class"]).to include("font-semibold", "text-ink") }
      it { expect(news_link["aria-current"]).to be_nil }
      it { expect(news_link["class"]).to include("text-ink-muted") }
    end

    context "when on a news article" do
      let_it_be(:news) { create(:news, :published) }
      let(:path) { news_path(slug: news.slug) }

      it { expect(news_link["aria-current"]).to eq("page") }
      it { expect(hall_link["aria-current"]).to be_nil }
    end

    context "when on the stats page" do
      let(:path) { stats_path }
      let(:stats_link) { menu.at_css("a[href='#{stats_path}']") }

      it { expect(stats_link.text).to eq(I18n.t("nav.stats")) }
      it { expect(stats_link["aria-current"]).to eq("page") }
      it { expect(news_link["aria-current"]).to be_nil }
    end
  end
end
