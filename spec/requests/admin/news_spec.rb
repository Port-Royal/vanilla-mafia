require "rails_helper"

RSpec.describe "Admin::News" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:editor) { create(:user, :editor) }
  let_it_be(:regular_user) { create(:user) }

  describe "GET /admin/news" do
    let_it_be(:published_article) { create(:news, :published) }
    let_it_be(:draft_article) { create(:news) }

    context "when user is admin" do
      before do
        sign_in admin
        get admin_news_index_path
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "shows all news including drafts" do
        expect(response.body).to include(published_article.title, draft_article.title)
      end

      it "renders delete button for draft articles" do
        assert_select "form[action='#{admin_news_path(draft_article)}'] button", text: I18n.t("admin_news.index.delete")
      end

      it "does not render delete button for published articles" do
        assert_select "form[action='#{admin_news_path(published_article)}'] button", text: I18n.t("admin_news.index.delete"), count: 0
      end

      it "renders unpublish button for published articles" do
        assert_select "form[action='#{unpublish_admin_news_path(published_article)}'] button", text: I18n.t("admin_news.index.unpublish")
      end

      it "does not render unpublish button for draft articles" do
        assert_select "form[action='#{unpublish_admin_news_path(draft_article)}'] button", text: I18n.t("admin_news.index.unpublish"), count: 0
      end

      it "renders unpublished before published" do
        draft_pos = response.body.index(draft_article.title)
        published_pos = response.body.index(published_article.title)
        expect(draft_pos).to be < published_pos
      end
    end

    context "when author has a linked player" do
      let_it_be(:player) { create(:player, name: "Автор-Игрок") }
      let_it_be(:author_with_player) { create(:user, :editor, player: player) }
      let_it_be(:article_with_player_author) { create(:news, author: author_with_player) }

      before do
        sign_in admin
        get admin_news_index_path
      end

      it "renders the player name instead of email" do
        expect(response.body).to include("Автор-Игрок")
        expect(response.body).not_to include(author_with_player.email)
      end

      it "links the player name to the player profile" do
        assert_select "a[href='#{player_path(player)}']", text: "Автор-Игрок"
      end
    end

    context "when author has no linked player" do
      before do
        sign_in admin
        get admin_news_index_path
      end

      it "renders the author email" do
        expect(response.body).to include(published_article.author.email)
      end
    end

    context "when user is editor" do
      before do
        sign_in editor
        get admin_news_index_path
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "shows all news including drafts" do
        expect(response.body).to include(published_article.title, draft_article.title)
      end

      it "does not render delete button" do
        assert_select "button", text: I18n.t("admin_news.index.delete"), count: 0
      end

      it "renders unpublish button for published articles" do
        assert_select "form[action='#{unpublish_admin_news_path(published_article)}'] button", text: I18n.t("admin_news.index.unpublish")
      end
    end

    context "when filtering by status" do
      before { sign_in admin }

      it "shows only drafts when filtered by draft" do
        get admin_news_index_path(status: :draft)
        expect(response.body).to include(draft_article.title)
        expect(response.body).not_to include(published_article.title)
      end

      it "shows only published when filtered by published" do
        get admin_news_index_path(status: :published)
        expect(response.body).to include(published_article.title)
        expect(response.body).not_to include(draft_article.title)
      end

      it "ignores invalid status filter" do
        get admin_news_index_path(status: :bogus)
        expect(response.body).to include(published_article.title, draft_article.title)
      end
    end

    context "when user is regular user" do
      before do
        sign_in regular_user
        get admin_news_index_path
      end

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      before { get admin_news_index_path }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/news/new" do
    context "when user is editor" do
      let_it_be(:root_competition) { create(:competition, :season, name: "Сезон 10") }
      let_it_be(:stage) { create(:competition, :series, parent: root_competition, name: "Серия 1") }

      before do
        sign_in editor
        get new_admin_news_path
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the new form" do
        expect(response.body).to include(I18n.t("admin_news.new.title"))
      end

      it "renders the competition selector" do
        assert_select "select[name='news[competition_id]']"
      end

      it "renders the season selector with seasons" do
        assert_select "select[data-cascade-select-target='parent'] option", text: "Сезон 10"
      end

      it "includes stages in the competition selector" do
        assert_select "select[name='news[competition_id]'] option", text: "Серия 1"
      end

      it "does not render the game selector" do
        assert_select "select[name='news[game_id]']", count: 0
      end

      it "renders a tall content editor" do
        assert_select "trix-editor[style*='min-height']"
      end
    end

    context "when user is regular user" do
      before do
        sign_in regular_user
        get new_admin_news_path
      end

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      before { get new_admin_news_path }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /admin/news" do
    context "when user is editor" do
      before { sign_in editor }

      context "with valid params" do
        let(:valid_params) { { news: { title: "Test Article", content: "Some content" } } }

        it "creates a news article" do
          expect {
            post admin_news_index_path, params: valid_params
          }.to change(News, :count).by(1)
        end

        it "sets the author to current user" do
          post admin_news_index_path, params: valid_params
          expect(News.last.author).to eq(editor)
        end

        it "defaults to draft status" do
          post admin_news_index_path, params: valid_params
          expect(News.last).to be_draft
        end

        it "redirects to index" do
          post admin_news_index_path, params: valid_params
          expect(response).to redirect_to(admin_news_index_path)
        end
      end

      context "with invalid params" do
        let(:invalid_params) { { news: { title: "" } } }

        it "does not create a news article" do
          expect {
            post admin_news_index_path, params: invalid_params
          }.not_to change(News, :count)
        end

        it "renders the form with errors" do
          post admin_news_index_path, params: invalid_params
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when user is regular user" do
      before { sign_in regular_user }

      it "returns not found" do
        post admin_news_index_path, params: { news: { title: "Test" } }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        post admin_news_index_path, params: { news: { title: "Test" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/news/:id" do
    let_it_be(:article) { create(:news, :published) }

    context "when user is editor" do
      before do
        sign_in editor
        get admin_news_path(article)
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "shows the article title" do
        expect(response.body).to include(article.title)
      end

      it "renders unpublish button for published articles" do
        assert_select "form[action='#{unpublish_admin_news_path(article)}'] button", text: I18n.t("admin_news.show.unpublish")
      end
    end

    context "when article is a draft" do
      let_it_be(:draft_article) { create(:news) }

      before do
        sign_in editor
        get admin_news_path(draft_article)
      end

      it "does not render unpublish button" do
        assert_select "form[action='#{unpublish_admin_news_path(draft_article)}'] button", count: 0
      end
    end

    context "when user is regular user" do
      before do
        sign_in regular_user
        get admin_news_path(article)
      end

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      before { get admin_news_path(article) }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/news/:id/edit" do
    let_it_be(:article) { create(:news) }

    context "when user is editor" do
      before do
        sign_in editor
        get edit_admin_news_path(article)
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the edit form" do
        expect(response.body).to include(I18n.t("admin_news.edit.title"))
      end
    end

    context "when user is regular user" do
      before do
        sign_in regular_user
        get edit_admin_news_path(article)
      end

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      before { get edit_admin_news_path(article) }

      it "redirects to sign in" do
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /admin/news/:id" do
    let!(:article) { create(:news, author: editor) }

    context "when user is editor" do
      before { sign_in editor }

      context "with valid params" do
        it "updates the article" do
          patch admin_news_path(article), params: { news: { title: "Updated Title" } }
          expect(article.reload.title).to eq("Updated Title")
        end

        it "redirects to show" do
          patch admin_news_path(article), params: { news: { title: "Updated Title" } }
          expect(response).to redirect_to(admin_news_path(article))
        end
      end

      context "with invalid params" do
        it "renders the form with errors" do
          patch admin_news_path(article), params: { news: { title: "" } }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when user is regular user" do
      before { sign_in regular_user }

      it "returns not found" do
        patch admin_news_path(article), params: { news: { title: "Hack" } }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        patch admin_news_path(article), params: { news: { title: "Hack" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /admin/news/:id" do
    context "when user is admin" do
      before { sign_in admin }

      it "deletes the article" do
        article = create(:news)
        expect {
          delete admin_news_path(article)
        }.to change(News, :count).by(-1)
      end

      it "redirects to index" do
        article = create(:news)
        delete admin_news_path(article)
        expect(response).to redirect_to(admin_news_index_path)
      end
    end

    context "when user is editor" do
      before { sign_in editor }

      it "returns not found" do
        article = create(:news)
        delete admin_news_path(article)
        expect(response).to have_http_status(:not_found)
      end

      it "does not delete the article" do
        article = create(:news)
        expect {
          delete admin_news_path(article)
        }.not_to change(News, :count)
      end
    end

    context "when user is regular user" do
      before { sign_in regular_user }

      it "returns not found" do
        article = create(:news)
        delete admin_news_path(article)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        article = create(:news)
        delete admin_news_path(article)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /admin/news/:id/publish" do
    context "when user is editor" do
      before { sign_in editor }

      context "when article is draft" do
        let(:article) { create(:news, author: editor) }

        it "publishes the article" do
          patch publish_admin_news_path(article)
          expect(article.reload).to be_published
        end

        it "sets published_at" do
          patch publish_admin_news_path(article)
          expect(article.reload.published_at).to be_present
        end

        it "redirects to show" do
          patch publish_admin_news_path(article)
          expect(response).to redirect_to(admin_news_path(article))
        end
      end

      context "when article has a scheduled published_at" do
        let(:scheduled_time) { 2.days.from_now }
        let(:article) { create(:news, author: editor, published_at: scheduled_time) }

        it "publishes the article" do
          patch publish_admin_news_path(article)
          expect(article.reload).to be_published
        end

        it "preserves the scheduled published_at" do
          patch publish_admin_news_path(article)
          expect(article.reload.published_at).to be_within(1.second).of(scheduled_time)
        end
      end

      context "when article is already published" do
        let_it_be(:article) { create(:news, :published) }

        it "returns unprocessable entity" do
          patch publish_admin_news_path(article)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when user is regular user" do
      let_it_be(:article) { create(:news) }

      before { sign_in regular_user }

      it "returns not found" do
        patch publish_admin_news_path(article)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      let_it_be(:article) { create(:news) }

      it "redirects to sign in" do
        patch publish_admin_news_path(article)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /admin/news/:id/unpublish" do
    context "when user is editor" do
      before { sign_in editor }

      context "when article is published" do
        let(:article) { create(:news, :published) }

        it "unpublishes the article" do
          patch unpublish_admin_news_path(article)
          expect(article.reload).to be_draft
        end

        it "preserves published_at" do
          original_published_at = article.published_at
          patch unpublish_admin_news_path(article)
          expect(article.reload.published_at).to eq(original_published_at)
        end

        it "redirects to index" do
          patch unpublish_admin_news_path(article)
          expect(response).to redirect_to(admin_news_index_path)
        end
      end

      context "when article is already a draft" do
        let(:article) { create(:news) }

        it "returns unprocessable entity" do
          patch unpublish_admin_news_path(article)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "when user is regular user" do
      let_it_be(:article) { create(:news, :published) }

      before { sign_in regular_user }

      it "returns not found" do
        patch unpublish_admin_news_path(article)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is not signed in" do
      let_it_be(:article) { create(:news, :published) }

      it "redirects to sign in" do
        patch unpublish_admin_news_path(article)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
