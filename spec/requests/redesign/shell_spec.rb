require "rails_helper"

RSpec.describe "Redesign layout shell" do
  let_it_be(:competition) { create(:competition, :season, :featured, name: "Season Featured") }

  let(:document) { Nokogiri::HTML(response.body) }
  let(:top_bar) { document.at_css("#site-top-bar") }
  let(:nav) { document.at_css("#site-top-bar nav") }
  let(:body) { document.at_css("body") }
  let(:path) { news_index_path }
  let(:design_cookie) { nil }
  let(:signed_in_user) { nil }

  before do
    cookies[:design] = design_cookie if design_cookie
    sign_in signed_in_user if signed_in_user
    get path
  end

  shared_examples "the new shell" do
    it { expect(top_bar).to be_present }
    it { expect(document.at_css("main#site-main")).to be_present }
    it { expect(document.at_css("#site-sidebar")).to be_nil }
    it { expect(document.at_css("#site-mobile-header")).to be_nil }
    it { expect(document.at_css("#mobile-nav")).to be_nil }
  end

  context "with the default design" do
    it { expect(document.at_css("aside#site-sidebar")).to be_present }
    it { expect(top_bar).to be_nil }
    it { expect(document.at_css("#site-main")).to be_nil }
    it { expect(body["class"]).to eq("min-h-screen bg-white font-sans") }
    it { expect(body["data-controller"]).to eq("menu time-zone") }
  end

  context "with the new design" do
    include_context "with the new design"

    it_behaves_like "the new shell"

    it { expect(top_bar.name).to eq("header") }
    it { expect(top_bar["class"]).to include("text-ink") }
    it { expect(nav.at_css("ul")["class"]).to include("py-1", "-my-1") }
    it { expect(body["class"]).to eq("min-h-screen bg-paper font-sans") }
    it { expect(body["data-controller"]).to eq("time-zone") }

    it "links the logo to the home page" do
      expect(top_bar.at_css("a[href='#{root_path}'] img.vm-logo")).to be_present
    end

    it "links the featured competition in the nav" do
      expect(nav.at_css("a[href='#{competition_path(slug: competition.slug)}']").text).to eq(competition.name)
    end

    it "lists the public links in today's order" do
      expect(nav.css("a").pluck("href"))
        .to eq([ competition_path(slug: competition.slug), hall_path, news_index_path ])
    end

    it "renders the page content inside main" do
      expect(document.at_css("main#site-main").text).to include(I18n.t("news.index.title"))
    end

    it "keeps a place for the signed-in menu" do
      expect(top_bar.at_css("#site-user-area")).to be_present
    end

    context "when signed out" do
      it "offers sign in as a ghost button" do
        expect(top_bar.at_css("#site-user-area a.vm-btn.vm-btn--ghost[href='#{new_user_session_path}']").text)
          .to eq(I18n.t("nav.sign_in"))
      end
    end

    context "when signed in" do
      let_it_be(:user) { create(:user) }
      let(:signed_in_user) { user }

      it { expect(top_bar.at_css("a[href='#{new_user_session_path}']")).to be_nil }
    end

    describe "locale switcher" do
      let(:locale_selector) { "form[action^='#{locale_path}']" }
      let(:locale_forms) { top_bar.at_css("#site-user-area").parent.css(locale_selector) }

      it "renders exactly one locale form in the desktop controls" do
        expect(locale_forms.size).to eq(1)
      end

      it "renders the locale forms only in the top bar: desktop controls and phone menu" do
        expect(document.css(locale_selector).size).to eq(top_bar.css(locale_selector).size).and eq(2)
      end

      it "posts the other locale" do
        expect(locale_forms.first["action"]).to eq(locale_path(locale: :en))
      end

      it "uses PATCH" do
        expect(locale_forms.first.at_css("input[name='_method']")["value"]).to eq("patch")
      end

      it "shows the current locale as plain text" do
        expect(top_bar.at_css(".vm-locale-current").text).to eq("RU")
      end

      it "marks the current locale" do
        expect(top_bar.at_css(".vm-locale-current")["aria-current"]).to eq("true")
      end

      it "tags the other locale button with its language" do
        expect(locale_forms.first.at_css("button")["lang"]).to eq("en")
      end

      it "names the other locale button in its own language" do
        expect(locale_forms.first.at_css("button")["aria-label"]).to eq("English")
      end
    end

    describe "active item" do
      let(:hall_link) { nav.at_css("a[href='#{hall_path}']") }
      let(:news_link) { nav.at_css("a[href='#{news_index_path}']") }

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

      context "when on a competition page" do
        let(:path) { competition_path(slug: competition.slug) }

        it { expect(nav.at_css("a[href='#{path}']")["aria-current"]).to eq("page") }
      end
    end
  end

  context "when the visitor opted in" do
    include_context "with the redesign offered"

    let(:design_cookie) { "new" }

    it_behaves_like "the new shell"
  end

  context "when the visitor declined" do
    include_context "with the redesign offered"

    let(:design_cookie) { "old" }

    it { expect(document.at_css("#site-sidebar")).to be_present }
    it { expect(top_bar).to be_nil }
  end

  context "when rendering a judge page" do
    include_context "with the new design"

    let_it_be(:judge) { create(:user, :judge) }
    let(:signed_in_user) { judge }
    let(:path) { judge_protocols_path }

    it_behaves_like "the new shell"

    it { expect(response).to have_http_status(:ok) }
  end

  context "when rendering an error page" do
    include_context "with the new design"

    let(:path) { competition_path(slug: "missing") }

    around do |example|
      env = Rails.application.env_config
      original_show = env["action_dispatch.show_exceptions"]
      original_local = env["action_dispatch.show_detailed_exceptions"]
      env["action_dispatch.show_exceptions"] = :all
      env["action_dispatch.show_detailed_exceptions"] = false
      example.run
    ensure
      env["action_dispatch.show_exceptions"] = original_show
      env["action_dispatch.show_detailed_exceptions"] = original_local
    end

    it_behaves_like "the new shell"

    it { expect(response).to have_http_status(:not_found) }
    it { expect(document.at_css("main#site-main").text).to include(I18n.t("errors.404.title")) }
  end
end
