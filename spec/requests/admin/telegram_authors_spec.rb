# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::TelegramAuthors" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:editor) { create(:user, :editor) }

  describe "POST /admin/telegram/authors" do
    context "when user is admin" do
      before { sign_in admin }

      it "creates a telegram author and redirects" do
        expect {
          post admin_telegram_authors_path, params: { telegram_author: { telegram_user_id: 999111 } }
        }.to change(TelegramAuthor, :count).by(1)
        expect(response).to redirect_to(admin_telegram_settings_path)
      end

      it "sets the telegram_user_id" do
        post admin_telegram_authors_path, params: { telegram_author: { telegram_user_id: 999222 } }

        expect(TelegramAuthor.last.telegram_user_id).to eq(999222)
      end

      it "links the telegram author to a user" do
        post admin_telegram_authors_path, params: { telegram_author: { telegram_user_id: 999333, user_id: admin.id } }

        expect(TelegramAuthor.last.user).to eq(admin)
      end

      context "with invalid params" do
        it "redirects with alert when telegram_user_id is blank" do
          expect {
            post admin_telegram_authors_path, params: { telegram_author: { telegram_user_id: "" } }
          }.not_to change(TelegramAuthor, :count)
          expect(response).to redirect_to(admin_telegram_settings_path)
          expect(flash[:alert]).to be_present
        end

        it "redirects with alert when telegram_user_id is duplicate" do
          create(:telegram_author, telegram_user_id: 888111)

          expect {
            post admin_telegram_authors_path, params: { telegram_author: { telegram_user_id: 888111 } }
          }.not_to change(TelegramAuthor, :count)
          expect(response).to redirect_to(admin_telegram_settings_path)
          expect(flash[:alert]).to be_present
        end
      end
    end

    context "when user is editor" do
      before { sign_in editor }

      it "returns not found" do
        post admin_telegram_authors_path, params: { telegram_author: { telegram_user_id: 123 } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /admin/telegram/authors/:id" do
    context "when user is admin" do
      let!(:author) { create(:telegram_author) }

      before { sign_in admin }

      it "destroys the telegram author and redirects" do
        expect {
          delete admin_telegram_author_path(author)
        }.to change(TelegramAuthor, :count).by(-1)
        expect(response).to redirect_to(admin_telegram_settings_path)
      end
    end

    context "when user is editor" do
      let!(:author) { create(:telegram_author) }

      before { sign_in editor }

      it "returns not found" do
        delete admin_telegram_author_path(author)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
