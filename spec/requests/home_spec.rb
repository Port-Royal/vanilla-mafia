require "rails_helper"

RSpec.describe HomeController do
  describe "GET /" do
    before { get root_path }

    it "returns success" do
      expect(response).to have_http_status(:ok)
    end

    it "does not redirect" do
      expect(response).not_to have_http_status(:redirect)
    end

    it "renders within the application layout" do
      expect(response.body).to include("Vanilla Mafia")
    end
  end
end
