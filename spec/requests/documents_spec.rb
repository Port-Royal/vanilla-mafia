require "rails_helper"

RSpec.describe "Documents" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:main) { document.at_css("main#site-main") }
  let(:rows) { document.css("#documents-list li a") }

  describe "GET /documents" do
    before { get documents_path }

    context "without published documents" do
      let_it_be(:draft) { create(:document, title: "Черновик") }

      it { expect(response).to have_http_status(:ok) }
      it { expect(main.at_css("h1").text).to eq(I18n.t("documents.index.title")) }
      it { expect(document.at_css("#documents-list")).to be_nil }
      it { expect(document.at_css("#documents-empty").text.strip).to eq(I18n.t("common.coming_soon")) }
    end

    context "with published documents" do
      let_it_be(:game_rules) { create(:document, :published, title: "Правила игры", slug: "game-rules", position: 2) }
      let_it_be(:league_rules) { create(:document, :published, title: "Регламент лиги", slug: "league-rules", position: 1) }
      let_it_be(:rating) { create(:document, :published, title: "Система рейтинга", slug: "rating-system", position: 2) }
      let_it_be(:draft) { create(:document, title: "Черновик", position: 0) }

      it { expect(rows.pluck("href")).to eq([ document_path(slug: "league-rules"), document_path(slug: "game-rules"), document_path(slug: "rating-system") ]) }
      it { expect(rows.map { |row| row.at_css("[data-part='title']").text }).to eq([ "Регламент лиги", "Правила игры", "Система рейтинга" ]) }
      it { expect(main.text).not_to include("Черновик") }
      it { expect(document.at_css("#documents-empty")).to be_nil }
    end
  end

  describe "GET /documents/:slug" do
    context "with a published document" do
      let_it_be(:rules) do
        create(:document, :published, title: "Правила игры", slug: "game-rules",
                                      body: "<h1>Ночь</h1><p>Мафия просыпается.</p>")
      end

      before { get document_path(slug: rules.slug) }

      it { expect(response).to have_http_status(:ok) }
      it { expect(main.at_css("h1").text).to eq("Правила игры") }
      it { expect(document.at_css("[data-part='body']").text).to include("Мафия просыпается.") }
      it { expect(document.at_css("[data-part='body']")["class"]).to include("news-prose") }
      it { expect(document.at_css("#documents-empty")).to be_nil }

      it "links back to the documents list" do
        expect(document.at_css("nav[aria-label='Breadcrumb'] a[href='#{documents_path}']").text)
          .to eq(I18n.t("documents.index.title"))
      end

      it { expect(document.at_css("nav[aria-label='Breadcrumb'] [aria-current='page']").text).to eq("Правила игры") }
    end

    context "with a published document without text" do
      let_it_be(:empty) { create(:document, :published, slug: "empty") }

      before { get document_path(slug: empty.slug) }

      it { expect(document.at_css("[data-part='body']")).to be_nil }
      it { expect(document.at_css("#documents-empty").text.strip).to eq(I18n.t("common.coming_soon")) }
    end

    context "with a draft" do
      let_it_be(:draft) { create(:document, slug: "draft") }

      before { get document_path(slug: draft.slug) }

      it { expect(response).to have_http_status(:not_found) }
    end

    context "with a draft and a signed-in user without any role" do
      let_it_be(:user) { create(:user) }
      let_it_be(:draft) { create(:document, slug: "draft") }

      before do
        sign_in user
        get document_path(slug: draft.slug)
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context "with a draft and a signed-in admin" do
      let_it_be(:admin) { create(:user, :admin) }
      let_it_be(:draft) { create(:document, title: "Регламент лиги", slug: "draft") }

      before do
        sign_in admin
        get document_path(slug: draft.slug)
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(document.at_css("main h1").text.strip).to eq("Регламент лиги") }
      it { expect(document.at_css("#document-draft").text.strip).to eq(I18n.t("documents.show.draft")) }
    end

    context "with a published document and a signed-in admin" do
      let_it_be(:admin) { create(:user, :admin) }
      let_it_be(:rules) { create(:document, :published, slug: "rules") }

      before do
        sign_in admin
        get document_path(slug: rules.slug)
      end

      it { expect(document.at_css("#document-draft")).to be_nil }
    end

    context "with an unknown slug" do
      before { get document_path(slug: "missing") }

      it { expect(response).to have_http_status(:not_found) }
    end

    context "when signed in without any role" do
      let_it_be(:user) { create(:user) }
      let_it_be(:rules) { create(:document, :published, slug: "rules") }

      before do
        sign_in user
        get document_path(slug: rules.slug)
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end
end
