# frozen_string_literal: true

require "rails_helper"

RSpec.describe Announcement, "scopes" do
  let_it_be(:admin_grant) { Grant.find_or_create_by!(code: "admin") }
  let_it_be(:editor_grant) { Grant.find_or_create_by!(code: "editor") }

  let_it_be(:user) { create(:user) }
  let_it_be(:admin_user) { create(:user) }
  let_it_be(:admin_user_grant) { create(:user_grant, user: admin_user, grant: admin_grant) }

  let_it_be(:public_announcement) { create(:announcement, grant_code: nil) }
  let_it_be(:admin_announcement) { create(:announcement, grant_code: "admin") }
  let_it_be(:editor_announcement) { create(:announcement, grant_code: "editor") }

  describe ".visible_to" do
    it "returns public announcements for any user" do
      expect(described_class.visible_to(user)).to include(public_announcement)
    end

    it "returns grant-specific announcements for users with that grant" do
      expect(described_class.visible_to(admin_user)).to include(admin_announcement)
    end

    it "excludes grant-specific announcements for users without that grant" do
      expect(described_class.visible_to(user)).not_to include(admin_announcement)
    end

    it "returns both public and matching grant announcements" do
      result = described_class.visible_to(admin_user)

      expect(result).to include(public_announcement, admin_announcement)
      expect(result).not_to include(editor_announcement)
    end
  end

  describe ".undismissed_by" do
    it "returns announcements the user has not dismissed" do
      expect(described_class.undismissed_by(user)).to include(public_announcement)
    end

    it "excludes announcements the user has dismissed" do
      create(:announcement_dismissal, user: user, announcement: public_announcement)

      expect(described_class.undismissed_by(user)).not_to include(public_announcement)
    end

    it "does not exclude announcements dismissed by other users" do
      other_user = create(:user)
      create(:announcement_dismissal, user: other_user, announcement: public_announcement)

      expect(described_class.undismissed_by(user)).to include(public_announcement)
    end
  end

  describe ".for_user" do
    it "returns visible and undismissed announcements" do
      result = described_class.for_user(admin_user)

      expect(result).to include(public_announcement, admin_announcement)
      expect(result).not_to include(editor_announcement)
    end

    it "excludes dismissed announcements" do
      create(:announcement_dismissal, user: admin_user, announcement: public_announcement)

      result = described_class.for_user(admin_user)

      expect(result).not_to include(public_announcement)
      expect(result).to include(admin_announcement)
    end
  end
end
