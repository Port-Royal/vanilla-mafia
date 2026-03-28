# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnnouncementDismissal do
  describe "validations" do
    subject { build(:announcement_dismissal) }

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:announcement_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:announcement) }
  end

  describe "indexes" do
    it "has a unique index on [user_id, announcement_id]" do
      index = ActiveRecord::Base.connection.indexes(:announcement_dismissals).find do |i|
        i.columns == %w[user_id announcement_id]
      end

      expect(index).to be_present
      expect(index.unique).to be(true)
    end
  end
end
