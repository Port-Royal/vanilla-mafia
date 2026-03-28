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

    it "renders full article content without truncation" do
      long_content = "A" * 400
      article = create(:news, :published, author: author, content: long_content)

      get news_index_path

      expect(response.body).to include(long_content)
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

  describe "GET /news/:id" do
    context "with a published article" do
      let_it_be(:article_with_content) do
        create(:news, :published, author: author, content: "Important announcement about the tournament")
      end

      it "renders successfully" do
        get news_path(article_with_content)
        expect(response).to have_http_status(:ok)
      end

      it "shows the article title" do
        get news_path(article_with_content)
        expect(response.body).to include(article_with_content.title)
      end

      it "renders the article content" do
        get news_path(article_with_content)
        expect(response.body).to include("Important announcement about the tournament")
      end
    end

    context "with a draft article" do
      it "returns not found for guests" do
        get news_path(draft_article)
        expect(response).to have_http_status(:not_found)
      end

      context "when signed in as an editor" do
        let_it_be(:editor) { create(:user, :editor) }

        before { sign_in editor }

        it "renders successfully" do
          get news_path(draft_article)
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "with a linked game" do
      let_it_be(:game) { create(:game) }
      let_it_be(:article_with_game) { create(:news, :published, author: author, game: game) }

      it "shows the game link" do
        get news_path(article_with_game)
        expect(response.body).to include(game_path(game))
      end
    end
  end
end
