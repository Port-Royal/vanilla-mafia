# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsController do
  let_it_be(:author) { create(:user) }
  let_it_be(:published_article) { create(:news, :published, author: author) }
  let_it_be(:draft_article) { create(:news, author: author) }

  describe "GET /news" do
    it "renders successfully" do
      get news_index_path
      expect(response).to have_http_status(:ok)
    end

    it "shows published articles" do
      get news_index_path
      expect(response.body).to include(published_article.title)
    end

    it "links article titles to the show page" do
      get news_index_path
      assert_select "a[href='#{news_path(published_article)}']", text: published_article.title
    end

    it "displays published_at with day, month name, and year" do
      get news_index_path
      expected_date = I18n.l(published_article.published_at, format: :full_date)
      expect(response.body).to include(expected_date)
    end

    it "excludes draft articles" do
      get news_index_path
      expect(response.body).not_to include(draft_article.title)
    end

    context "when article content exceeds max length setting" do
      let(:long_content) { "<p>First paragraph.</p><p>Second paragraph with more text.</p><p>Third paragraph.</p>" }
      let(:short_article) { create(:news, :published, author: author, content: long_content) }

      before do
        FeatureToggle.create!(key: "news_max_article_length", enabled: true, value: "30")
        short_article
      end

      after { FeatureToggle.find_by(key: "news_max_article_length")&.destroy }

      it "truncates at paragraph boundary" do
        get news_index_path
        expect(response.body).to include("First paragraph.")
        expect(response.body).not_to include("Third paragraph.")
      end

      it "shows a Read more link" do
        get news_index_path
        assert_select "a[href='#{news_path(short_article)}']", text: I18n.t("news.index.read_more")
      end
    end

    context "when article has photos" do
      let(:article_with_photo) { create(:news, :published, :with_photo, author: author) }

      it "renders the photo" do
        article_with_photo
        get news_index_path
        assert_select "img[src*='photo.jpg']"
      end
    end

    context "when user is an editor" do
      let_it_be(:editor) { create(:user, :editor) }

      before { sign_in editor }

      it "shows edit link" do
        get news_index_path
        expect(response.body).to include(edit_admin_news_path(published_article))
      end
    end

    context "when user is not signed in" do
      it "does not show edit link" do
        get news_index_path
        expect(response.body).not_to include(edit_admin_news_path(published_article))
      end
    end

    context "when user has no editor grant" do
      let_it_be(:regular_user) { create(:user) }

      before { sign_in regular_user }

      it "does not show edit link" do
        get news_index_path
        expect(response.body).not_to include(edit_admin_news_path(published_article))
      end
    end

    context "when classic pagination is enabled" do
      before { FeatureToggle.create!(key: "news_classic_pagination", enabled: true) }
      after { FeatureToggle.find_by(key: "news_classic_pagination").destroy }

      it "renders pagy navigation" do
        create_list(:news, 26, :published, author: author)
        get news_index_path
        assert_select "nav[aria-label]"
      end

      context "when news_per_page is configured" do
        before { FeatureToggle.create!(key: "news_per_page", enabled: true, value: "5") }
        after { FeatureToggle.find_by(key: "news_per_page").destroy }

        it "paginates with the configured limit" do
          create_list(:news, 6, :published, author: author)
          get news_index_path
          assert_select "article", count: 5
        end
      end
    end

    context "when infinite scroll is enabled" do
      before { FeatureToggle.create!(key: "news_infinite_scroll", enabled: true) }
      after { FeatureToggle.find_by(key: "news_infinite_scroll").destroy }

      it "wraps articles in a turbo frame" do
        get news_index_path
        assert_select "turbo-frame#news-list"
      end

      it "renders a sentinel for loading more" do
        create_list(:news, 25, :published, author: author)
        get news_index_path
        assert_select "[data-infinite-scroll-target='sentinel']"
      end

      it "does not render pagy navigation" do
        get news_index_path
        assert_select "nav[aria-label]", count: 0
      end

      context "when requesting a subsequent page as turbo stream" do
        before { create_list(:news, 25, :published, author: author) }

        it "returns turbo stream response" do
          get news_index_path(page: 2, format: :turbo_stream)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        end
      end
    end

    context "when both pagination flags are enabled" do
      before do
        FeatureToggle.create!(key: "news_classic_pagination", enabled: true)
        FeatureToggle.create!(key: "news_infinite_scroll", enabled: true)
      end
      after do
        FeatureToggle.where(key: %w[news_classic_pagination news_infinite_scroll]).destroy_all
      end

      it "uses classic pagination" do
        get news_index_path
        assert_select "turbo-frame#news-list", count: 0
      end
    end

    context "when both pagination flags are off" do
      it "loads all news without pagination" do
        create_list(:news, 30, :published, author: author)
        get news_index_path
        assert_select "article", minimum: 30
        assert_select "nav[aria-label]", count: 0
      end
    end

    context "when there are no published articles" do
      before { News.update_all(status: :draft, published_at: nil) }

      after { published_article.update!(status: :published, published_at: Time.current) }

      it "shows empty message" do
        get news_index_path
        expect(response.body).to include(I18n.t("news.index.empty"))
      end
    end
  end

  describe "GET /news/:id" do
    it "returns success" do
      get news_path(published_article)
      expect(response).to have_http_status(:ok)
    end

    it "shows the full article content" do
      get news_path(published_article)
      expect(response.body).to include(published_article.title)
    end

    it "shows a back link to news index" do
      get news_path(published_article)
      assert_select "a[href='#{news_index_path}']", text: I18n.t("news.show.back")
    end

    it "returns not found for draft articles" do
      get news_path(draft_article)
      expect(response).to have_http_status(:not_found)
    end
  end
end
