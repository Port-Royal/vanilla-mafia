require "rails_helper"
require_relative "../../db/migrate/20260330052010_seed_release_announcements"

RSpec.describe SeedReleaseAnnouncements do
  describe "#up" do
    it "creates announcements with version 1.3.0" do
      described_class.new.up

      expect(Announcement.where(version: "1.3.0").count).to be >= 3
    end

    it "creates a subscriber announcement about podcast features" do
      described_class.new.up

      announcement = Announcement.find_by(version: "1.3.0", grant_code: "subscriber")
      expect(announcement).to be_present
      expect(announcement.message_ru).to be_present
      expect(announcement.message_en).to be_present
    end

    it "creates a judge announcement about help section" do
      described_class.new.up

      announcement = Announcement.find_by(version: "1.3.0", grant_code: "judge")
      expect(announcement).to be_present
      expect(announcement.message_ru).to be_present
      expect(announcement.message_en).to be_present
    end

    it "creates an admin announcement about help section" do
      described_class.new.up

      announcement = Announcement.find_by(version: "1.3.0", grant_code: "admin")
      expect(announcement).to be_present
      expect(announcement.message_ru).to be_present
      expect(announcement.message_en).to be_present
    end

    it "creates a general announcement about news improvements" do
      described_class.new.up

      announcement = Announcement.find_by(version: "1.3.0", grant_code: nil)
      expect(announcement).to be_present
      expect(announcement.message_ru).to be_present
      expect(announcement.message_en).to be_present
    end

    it "is idempotent" do
      described_class.new.up
      count_after_first = Announcement.where(version: "1.3.0").count

      described_class.new.up
      count_after_second = Announcement.where(version: "1.3.0").count

      expect(count_after_second).to eq(count_after_first)
    end
  end

  describe "#down" do
    it "removes all 1.3.0 announcements" do
      described_class.new.up
      expect(Announcement.where(version: "1.3.0").count).to be > 0

      described_class.new.down

      expect(Announcement.where(version: "1.3.0").count).to eq(0)
    end
  end
end
