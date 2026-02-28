require "rails_helper"

RSpec.describe SetLocale, type: :request do
  context "when guest with no cookie" do
    it "uses default locale" do
      get root_path
      expect(response.body).to include('lang="ru"')
    end
  end

  context "when guest with locale cookie" do
    before { cookies[:locale] = "en" }

    it "uses cookie locale" do
      get root_path
      expect(response.body).to include('lang="en"')
    end
  end

  context "when guest with invalid cookie" do
    before { cookies[:locale] = "xx" }

    it "falls back to default locale" do
      get root_path
      expect(response.body).to include('lang="ru"')
    end
  end

  context "when signed-in user" do
    let(:user) { create(:user, locale: "en") }

    before { sign_in user }

    it "uses user locale" do
      get root_path
      expect(response.body).to include('lang="en"')
    end
  end

  context "when signed-in user with conflicting cookie" do
    let(:user) { create(:user, locale: "en") }

    before do
      sign_in user
      cookies[:locale] = "ru"
    end

    it "user locale wins over cookie" do
      get root_path
      expect(response.body).to include('lang="en"')
    end
  end
end
