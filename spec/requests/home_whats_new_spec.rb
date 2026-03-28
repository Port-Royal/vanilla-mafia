# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home What's New block" do
  let_it_be(:user) { create(:user) }
  let_it_be(:announcement) { create(:announcement, version: "2.0.0", message: "New feature released") }

  context "when signed in with home_whats_new enabled" do
    let!(:toggle) { create(:feature_toggle, key: "home_whats_new", enabled: true) }

    before do
      sign_in user
      get root_path
    end

    it "renders the What's New section title" do
      expect(response.body).to include(I18n.t("home.whats_new.title"))
    end

    it "renders the version heading" do
      expect(response.body).to include(I18n.t("home.whats_new.version", version: "2.0.0"))
    end

    it "renders the announcement message" do
      expect(response.body).to include("New feature released")
    end

    it "renders the dismiss button" do
      expect(response.body).to include(I18n.t("home.whats_new.dismiss"))
    end

    it "includes announcement IDs in dismiss button data" do
      expect(response.body).to include("data-announcement-ids=\"#{announcement.id}\"")
    end
  end

  context "when home_whats_new toggle is disabled" do
    let!(:toggle) { create(:feature_toggle, key: "home_whats_new", enabled: false) }

    before do
      sign_in user
      get root_path
    end

    it "does not render the What's New section" do
      expect(response.body).not_to include(I18n.t("home.whats_new.title"))
    end
  end

  context "when user is not signed in" do
    let!(:toggle) { create(:feature_toggle, key: "home_whats_new", enabled: true) }

    before { get root_path }

    it "does not render the What's New section" do
      expect(response.body).not_to include(I18n.t("home.whats_new.title"))
    end
  end

  context "when all announcements are dismissed" do
    let!(:toggle) { create(:feature_toggle, key: "home_whats_new", enabled: true) }
    let!(:dismissal) { create(:announcement_dismissal, user: user, announcement: announcement) }

    before do
      sign_in user
      get root_path
    end

    it "does not render the What's New section" do
      expect(response.body).not_to include(I18n.t("home.whats_new.title"))
    end
  end

  context "with multiple versions" do
    let!(:toggle) { create(:feature_toggle, key: "home_whats_new", enabled: true) }
    let!(:announcement2) { create(:announcement, version: "2.1.0", message: "Another update") }

    before do
      sign_in user
      get root_path
    end

    it "renders both version headings" do
      expect(response.body).to include(I18n.t("home.whats_new.version", version: "2.0.0"))
      expect(response.body).to include(I18n.t("home.whats_new.version", version: "2.1.0"))
    end
  end
end
