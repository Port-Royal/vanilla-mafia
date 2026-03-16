require "rails_helper"

RSpec.describe "Legacy redirects" do
  describe "GET /seasons/:number" do
    context "when matching competition exists" do
      let_it_be(:competition) { create(:competition, :season, slug: "season-5", legacy_season: 5) }

      it "redirects to the competition page" do
        get "/seasons/5"
        expect(response).to redirect_to(competition_path(slug: competition.slug))
      end

      it "returns moved permanently status" do
        get "/seasons/5"
        expect(response).to have_http_status(:moved_permanently)
      end
    end

    context "when no matching competition exists" do
      it "returns not found" do
        get "/seasons/999"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /seasons/:season_number/series/:number" do
    context "when matching competition exists" do
      let_it_be(:parent) { create(:competition, :season, legacy_season: 5) }
      let_it_be(:series) { create(:competition, :series, slug: "season-5-series-3", legacy_season: 5, legacy_series: 3, parent: parent) }

      it "redirects to the competition page" do
        get "/seasons/5/series/3"
        expect(response).to redirect_to(competition_path(slug: series.slug))
      end

      it "returns moved permanently status" do
        get "/seasons/5/series/3"
        expect(response).to have_http_status(:moved_permanently)
      end
    end

    context "when no matching competition exists" do
      it "returns not found" do
        get "/seasons/5/series/999"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET / (root)" do
    let_it_be(:competition) { create(:competition, :season, slug: "season-5", legacy_season: 5) }

    it "redirects to the current season competition" do
      get "/"
      expect(response).to redirect_to(competition_path(slug: competition.slug))
    end
  end
end
