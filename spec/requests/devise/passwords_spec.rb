require "rails_helper"

RSpec.describe "Devise::Passwords" do
  describe "POST /users/password (paranoid mode)" do
    let(:existing_user) { create(:user) }

    it "shows the generic paranoid flash for an unknown email" do
      post user_password_path, params: { user: { email: "no-such-user@example.com" } }

      expect(flash[:notice]).to eq(I18n.t("devise.passwords.send_paranoid_instructions"))
    end

    it "shows the generic paranoid flash for a known email" do
      post user_password_path, params: { user: { email: existing_user.email } }

      expect(flash[:notice]).to eq(I18n.t("devise.passwords.send_paranoid_instructions"))
    end

    it "redirects to sign_in in both cases so outcome is indistinguishable" do
      post user_password_path, params: { user: { email: "no-such-user@example.com" } }
      expect(response).to redirect_to(new_user_session_path)

      post user_password_path, params: { user: { email: existing_user.email } }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
