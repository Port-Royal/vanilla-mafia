require "rails_helper"

RSpec.describe "Devise::Sessions" do
  describe "GET /users/sign_in" do
    it "displays the Google sign-in button" do
      get new_user_session_path
      expect(response.body).to include("google_oauth2")
    end

    it "includes sign in with Google text" do
      get new_user_session_path
      expect(response.body).to include(I18n.t("devise.shared.links.sign_in_with_google"))
    end
  end

  describe "GET /users/sign_up" do
    it "displays the Google sign-in button" do
      get new_user_registration_path
      expect(response.body).to include("google_oauth2")
    end

    it "includes sign in with Google text" do
      get new_user_registration_path
      expect(response.body).to include(I18n.t("devise.shared.links.sign_in_with_google"))
    end
  end
end
