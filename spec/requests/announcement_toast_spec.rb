# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Announcement toast notification" do
  let_it_be(:user) { create(:user) }
  let_it_be(:announcement) { create(:announcement, version: "2.0.0", message: "Toast update") }

  context "when signed in with toast_whats_new enabled" do
    let!(:toggle) { create(:feature_toggle, key: "toast_whats_new", enabled: true) }

    before do
      sign_in user
      get root_path
    end

    it "renders the toast container with fixed positioning" do
      expect(response.body).to include("fixed bottom-4 right-4")
    end

    it "renders the announcement message in the toast" do
      expect(response.body).to include("Toast update")
    end

    it "renders the dismiss button" do
      expect(response.body).to include("announcement-dismiss#dismiss")
    end

    it "includes announcement IDs in dismiss button data" do
      expect(response.body).to include("data-announcement-ids=\"#{announcement.id}\"")
    end

    it "renders the toast-specific title" do
      expect(response.body).to include(I18n.t("home.whats_new.toast_title"))
    end
  end

  context "when toast_whats_new toggle is disabled" do
    let!(:toggle) { create(:feature_toggle, key: "toast_whats_new", enabled: false) }

    before do
      sign_in user
      get root_path
    end

    it "does not render the toast" do
      expect(response.body).not_to include("fixed bottom-4 right-4")
    end
  end

  context "when user is not signed in" do
    let!(:toggle) { create(:feature_toggle, key: "toast_whats_new", enabled: true) }

    before { get root_path }

    it "does not render the toast" do
      expect(response.body).not_to include("fixed bottom-4 right-4")
    end
  end

  context "when all announcements are dismissed" do
    let!(:toggle) { create(:feature_toggle, key: "toast_whats_new", enabled: true) }
    let!(:dismissal) { create(:announcement_dismissal, user: user, announcement: announcement) }

    before do
      sign_in user
      get root_path
    end

    it "does not render the toast" do
      expect(response.body).not_to include("fixed bottom-4 right-4")
    end
  end
end
