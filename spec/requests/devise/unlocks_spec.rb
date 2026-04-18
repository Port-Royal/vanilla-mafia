require "rails_helper"

RSpec.describe "Devise::Unlocks" do
  let(:password) { "Str0ng!pass" }
  let(:user) { create(:user, password: password) }

  describe "POST /users/sign_in with bad password" do
    it "locks the account after the configured maximum_attempts" do
      Devise.maximum_attempts.times do
        post user_session_path, params: { user: { email: user.email, password: "wrong" } }
      end

      expect(user.reload.access_locked?).to be true
    end

    it "rejects sign-in for a locked account even with the correct password" do
      user.lock_access!
      post user_session_path, params: { user: { email: user.email, password: password } }

      expect(response.body).to include(I18n.t("devise.failure.locked"))
    end
  end

  describe "GET /users/unlock" do
    let(:locked_user) { create(:user, password: password) }

    it "unlocks the account when given a valid token" do
      raw_token, encrypted_token = Devise.token_generator.generate(User, :unlock_token)
      locked_user.update_columns(unlock_token: encrypted_token, locked_at: Time.current, failed_attempts: Devise.maximum_attempts)

      get user_unlock_path, params: { unlock_token: raw_token }

      expect(locked_user.reload.access_locked?).to be false
    end

    it "leaves the account locked for an invalid token" do
      locked_user.lock_access!

      get user_unlock_path, params: { unlock_token: "bogus" }

      expect(locked_user.reload.access_locked?).to be true
    end
  end
end
