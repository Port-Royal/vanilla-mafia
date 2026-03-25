require "rails_helper"

RSpec.describe "OmniAuth Callbacks" do
  before do
    @previous_omniauth_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = @previous_omniauth_test_mode
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  let(:google_auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "123456789",
      info: {
        email: "test@example.com",
        name: "Test User"
      },
      extra: {
        raw_info: {
          email_verified: true
        }
      }
    )
  end

  describe "GET /users/auth/google_oauth2/callback" do
    before do
      OmniAuth.config.mock_auth[:google_oauth2] = google_auth_hash
    end

    context "when user does not exist" do
      it "creates a new user" do
        expect {
          get "/users/auth/google_oauth2/callback"
        }.to change(User, :count).by(1)
      end

      it "sets provider and uid on the new user" do
        get "/users/auth/google_oauth2/callback"
        user = User.last
        expect(user.provider).to eq("google_oauth2")
        expect(user.uid).to eq("123456789")
      end

      it "sets email from OAuth data" do
        get "/users/auth/google_oauth2/callback"
        expect(User.last.email).to eq("test@example.com")
      end

      it "signs in the user" do
        get "/users/auth/google_oauth2/callback"
        expect(request.env["warden"].user(:user)).to be_present
      end

      it "redirects after sign in" do
        get "/users/auth/google_oauth2/callback"
        expect(response).to redirect_to(root_path)
      end
    end

    context "when user exists with same provider and uid" do
      let!(:existing_user) do
        create(:user, provider: "google_oauth2", uid: "123456789", email: "test@example.com")
      end

      it "does not create a new user" do
        expect {
          get "/users/auth/google_oauth2/callback"
        }.not_to change(User, :count)
      end

      it "signs in the existing user" do
        get "/users/auth/google_oauth2/callback"
        expect(request.env["warden"].user(:user)).to eq(existing_user)
      end
    end

    context "when user exists with same email but no OAuth" do
      let!(:existing_user) { create(:user, email: "test@example.com") }

      it "does not create a new user" do
        expect {
          get "/users/auth/google_oauth2/callback"
        }.not_to change(User, :count)
      end

      it "links OAuth identity to existing user" do
        get "/users/auth/google_oauth2/callback"
        existing_user.reload
        expect(existing_user.provider).to eq("google_oauth2")
        expect(existing_user.uid).to eq("123456789")
      end

      it "signs in the existing user" do
        get "/users/auth/google_oauth2/callback"
        expect(request.env["warden"].user(:user)).to eq(existing_user)
      end
    end

    context "when email is not verified" do
      let(:unverified_auth_hash) do
        OmniAuth::AuthHash.new(
          provider: "google_oauth2",
          uid: "987654321",
          info: { email: "unverified@example.com" },
          extra: { raw_info: { email_verified: false } }
        )
      end

      before do
        OmniAuth.config.mock_auth[:google_oauth2] = unverified_auth_hash
      end

      it "does not create a user" do
        expect {
          get "/users/auth/google_oauth2/callback"
        }.not_to change(User, :count)
      end

      it "redirects to sign in" do
        get "/users/auth/google_oauth2/callback"
        expect(response).to redirect_to(new_user_session_path)
      end

      it "does not link to existing account" do
        create(:user, email: "unverified@example.com")
        get "/users/auth/google_oauth2/callback"
        expect(User.find_by(email: "unverified@example.com").provider).to be_nil
      end
    end

    context "when email has different casing" do
      let!(:existing_user) { create(:user, email: "test@example.com") }

      let(:mixed_case_auth_hash) do
        OmniAuth::AuthHash.new(
          provider: "google_oauth2",
          uid: "123456789",
          info: { email: "Test@Example.COM" },
          extra: { raw_info: { email_verified: true } }
        )
      end

      before do
        OmniAuth.config.mock_auth[:google_oauth2] = mixed_case_auth_hash
      end

      it "links to existing account by normalized email" do
        get "/users/auth/google_oauth2/callback"
        existing_user.reload
        expect(existing_user.provider).to eq("google_oauth2")
      end
    end

    context "when OAuth authentication fails" do
      before do
        OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
      end

      it "does not create a user" do
        expect {
          get "/users/auth/google_oauth2/callback"
        }.not_to change(User, :count)
      end
    end
  end
end
