require "rails_helper"

RSpec.describe NotificationSettingsController do
  describe "GET /notification_settings/edit" do
    context "when user is an editor" do
      let_it_be(:editor) { create(:user, :editor) }

      before { sign_in editor }

      it "renders the notification settings form" do
        get edit_notification_settings_path
        expect(response).to have_http_status(:ok)
      end

      it "displays the news draft notification toggle" do
        get edit_notification_settings_path
        assert_select "input[name='user[notify_on_news_draft]']"
      end
    end

    context "when user is an admin" do
      let_it_be(:admin) { create(:user, :admin) }

      before { sign_in admin }

      it "renders the notification settings form" do
        get edit_notification_settings_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is a regular user" do
      let_it_be(:user) { create(:user) }

      before { sign_in user }

      it "redirects to root" do
        get edit_notification_settings_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in" do
        get edit_notification_settings_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /notification_settings" do
    context "when user is an editor" do
      let_it_be(:editor) { create(:user, :editor, notify_on_news_draft: true) }

      before { sign_in editor }

      it "updates the notification setting" do
        patch notification_settings_path, params: { user: { notify_on_news_draft: "0" } }
        expect(editor.reload.notify_on_news_draft).to be false
      end

      it "redirects with a success notice" do
        patch notification_settings_path, params: { user: { notify_on_news_draft: "0" } }
        expect(response).to redirect_to(edit_notification_settings_path)
      end
    end

    context "when user is a regular user" do
      let_it_be(:user) { create(:user) }

      before { sign_in user }

      it "redirects to root" do
        patch notification_settings_path, params: { user: { notify_on_news_draft: "0" } }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
