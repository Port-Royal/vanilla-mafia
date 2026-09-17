require "rails_helper"

RSpec.describe HelpController do
  describe "GET /help" do
    it "renders the help index" do
      get help_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("help.index.title"))
    end

    it "always lists the pages that are not tied to a feature" do
      get help_index_path

      expect(response.body).to include(I18n.t("help.pages.obs-overlay.title"))
        .and include(I18n.t("help.pages.podcast-feed.title"))
    end

    context "when the game breakdown toggle is on" do
      let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }

      it "lists the breakdown page" do
        get help_index_path
        expect(response.body).to include(I18n.t("help.pages.game-breakdown.title"))
      end
    end

    context "when the game breakdown toggle is off" do
      let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: false) }

      it "hides the breakdown page" do
        get help_index_path
        expect(response.body).not_to include(I18n.t("help.pages.game-breakdown.title"))
      end
    end

    context "when the game breakdown toggle was never set" do
      it "hides the breakdown page" do
        get help_index_path
        expect(response.body).not_to include(I18n.t("help.pages.game-breakdown.title"))
      end
    end
  end

  describe "GET /help/game-breakdown" do
    context "when the toggle is on" do
      let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }

      it "renders the page" do
        get help_path(slug: "game-breakdown")
        expect(response).to have_http_status(:ok)
      end

      it "renders every section" do
        get help_path(slug: "game-breakdown")

        expect(response.body).to include(I18n.t("help.pages.game-breakdown.difference_title"))
          .and include(I18n.t("help.pages.game-breakdown.create_title"))
          .and include(I18n.t("help.pages.game-breakdown.roles_mode_title"))
          .and include(I18n.t("help.pages.game-breakdown.phases_title"))
          .and include(I18n.t("help.pages.game-breakdown.automatic_title"))
          .and include(I18n.t("help.pages.game-breakdown.warnings_title"))
          .and include(I18n.t("help.pages.game-breakdown.result_title"))
          .and include(I18n.t("help.pages.game-breakdown.view_title"))
      end
    end

    # The page would describe something the reader cannot reach.
    context "when the toggle is off" do
      let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: false) }

      it "returns not found" do
        get help_path(slug: "game-breakdown")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the toggle was never set" do
      it "returns not found" do
        get help_path(slug: "game-breakdown")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /help/:slug" do
    context "when help page exists" do
      it "renders the page" do
        get help_path(slug: "obs-overlay")

        expect(response).to have_http_status(:ok)
      end

      it "renders OBS overlay help content" do
        get help_path(slug: "obs-overlay")

        expect(response.body).to include(I18n.t("help.pages.obs-overlay.setup_title"))
        expect(response.body).to include(I18n.t("help.pages.obs-overlay.recommended_title"))
        expect(response.body).to include(I18n.t("help.pages.obs-overlay.params_title"))
        expect(response.body).to include(I18n.t("help.pages.obs-overlay.judge_title"))
        expect(response.body).to include(I18n.t("help.pages.obs-overlay.realtime_title"))
      end
    end

    context "when podcast feed help page is requested" do
      it "renders the page" do
        get help_path(slug: "podcast-feed")

        expect(response).to have_http_status(:ok)
      end

      it "renders podcast feed help content" do
        get help_path(slug: "podcast-feed")

        expect(response.body).to include(I18n.t("help.pages.podcast-feed.title"))
        expect(response.body).to include(I18n.t("help.pages.podcast-feed.intro"))
        expect(response.body).to include(I18n.t("help.pages.podcast-feed.apple_title"))
        expect(response.body).to include(I18n.t("help.pages.podcast-feed.pocket_casts_title"))
        expect(response.body).to include(I18n.t("help.pages.podcast-feed.castbox_title"))
        expect(response.body).to include(I18n.t("help.pages.podcast-feed.generic_title"))
        expect(response.body).to include(I18n.t("help.pages.podcast-feed.privacy_title"))
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
