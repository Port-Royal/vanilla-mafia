require "rails_helper"

RSpec.describe "Admin::TelegramSettings" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:editor) { create(:user, :editor) }
  let_it_be(:regular_user) { create(:user) }

  describe "GET /admin/telegram" do
    let(:webhook_result) do
      Telegram::WebhookInfoService::Result.new(success: true, url: "https://example.com/webhooks/telegram", pending_update_count: 0, description: nil)
    end

    before do
      allow(Telegram::WebhookInfoService).to receive(:call).and_return(webhook_result)
    end

    context "when user is admin" do
      before do
        sign_in admin
        get admin_telegram_settings_path
      end

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when user is editor" do
      before { sign_in editor }

      it "returns not found" do
        get admin_telegram_settings_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when user is regular user" do
      before { sign_in regular_user }

      it "returns not found" do
        get admin_telegram_settings_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not signed in" do
      it "redirects to sign in" do
        get admin_telegram_settings_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with telegram authors" do
      let_it_be(:author) { create(:telegram_author, telegram_username: "bot_user") }

      before do
        sign_in admin
        get admin_telegram_settings_path
      end

      it "displays the telegram author" do
        expect(response.body).to include("bot_user")
      end
    end
  end
end
