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

    it "excludes draft articles" do
      get news_index_path
      expect(response.body).not_to include(draft_article.title)
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
end
