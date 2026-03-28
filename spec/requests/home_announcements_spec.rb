# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home announcements" do
  let_it_be(:user) { create(:user) }
  let_it_be(:announcement) { create(:announcement, version: "1.0.0") }

  context "when user is signed in" do
    before { sign_in user }

    context "when home_whats_new toggle is enabled" do
      let!(:toggle) { create(:feature_toggle, key: "home_whats_new", enabled: true) }

      it "loads announcements for the user" do
        get root_path

        expect(controller.instance_variable_get(:@announcements)).to include(announcement)
      end
    end

    context "when toast_whats_new toggle is enabled" do
      let!(:toggle) { create(:feature_toggle, key: "toast_whats_new", enabled: true) }

      it "loads announcements for the user" do
        get root_path

        expect(controller.instance_variable_get(:@announcements)).to include(announcement)
      end
    end

    context "when both toggles are disabled" do
      let!(:block_toggle) { create(:feature_toggle, key: "home_whats_new", enabled: false) }
      let!(:toast_toggle) { create(:feature_toggle, key: "toast_whats_new", enabled: false) }

      it "does not load announcements" do
        get root_path

        expect(controller.instance_variable_get(:@announcements)).to be_nil
      end
    end

    context "when user has dismissed an announcement" do
      let!(:toggle) { create(:feature_toggle, key: "home_whats_new", enabled: true) }
      let!(:dismissal) { create(:announcement_dismissal, user: user, announcement: announcement) }

      it "excludes dismissed announcements" do
        get root_path

        expect(controller.instance_variable_get(:@announcements)).not_to include(announcement)
      end
    end
  end

  context "when user is not signed in" do
    context "when toggle is enabled" do
      let!(:toggle) { create(:feature_toggle, key: "home_whats_new", enabled: true) }

      it "does not load announcements" do
        get root_path

        expect(controller.instance_variable_get(:@announcements)).to be_nil
      end
    end
  end
end
