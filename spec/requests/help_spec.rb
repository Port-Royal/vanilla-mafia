require "rails_helper"

RSpec.describe HelpController do
  describe "GET /help" do
    it "renders the help index" do
      get help_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("help.index.title"))
    end
  end

  describe "GET /help/:slug" do
    context "when help page exists" do
      it "renders the page" do
        get help_path(slug: "obs-overlay")

        expect(response).to have_http_status(:ok)
      end
    end

    context "when help page does not exist" do
      it "returns not found" do
        get help_path(slug: "nonexistent-page")

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
