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

    it "renders full article content" do
      content = "A" * 4000
      create(:news, :published, author: author, content: content)

      get news_index_path

      expect(response.body).to include(content)
    end

    it "excludes draft articles" do
      get news_index_path
      expect(response.body).not_to include(draft_article.title)
    end

    it "does not link article titles to a show page" do
      get news_index_path
      assert_select "a[href=?]", "/news/#{published_article.id}", count: 0
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
    it "redirects to the news index" do
      get "/news/#{published_article.id}"
      expect(response).to redirect_to("/news")
    end
  end
end
