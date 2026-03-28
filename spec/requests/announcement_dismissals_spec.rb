# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /announcements/dismiss" do
  let_it_be(:user) { create(:user) }
  let_it_be(:announcement1) { create(:announcement, version: "1.0.0") }
  let_it_be(:announcement2) { create(:announcement, version: "1.0.1") }

  context "when signed in" do
    before { sign_in user }

    it "creates dismissals for the given announcement IDs" do
      expect {
        post announcement_dismissals_path, params: { announcement_ids: [ announcement1.id, announcement2.id ] }
      }.to change(AnnouncementDismissal, :count).by(2)
    end

    it "responds with success" do
      post announcement_dismissals_path, params: { announcement_ids: [ announcement1.id ] }

      expect(response).to have_http_status(:ok)
    end

    it "ignores already-dismissed announcements" do
      create(:announcement_dismissal, user: user, announcement: announcement1)

      expect {
        post announcement_dismissals_path, params: { announcement_ids: [ announcement1.id, announcement2.id ] }
      }.to change(AnnouncementDismissal, :count).by(1)
    end

    it "handles missing announcement_ids param" do
      expect {
        post announcement_dismissals_path, params: {}
      }.not_to change(AnnouncementDismissal, :count)

      expect(response).to have_http_status(:ok)
    end
  end

  context "when not signed in" do
    it "redirects to sign in" do
      post announcement_dismissals_path, params: { announcement_ids: [ announcement1.id ] }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
