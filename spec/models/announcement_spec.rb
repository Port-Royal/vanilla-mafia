# frozen_string_literal: true

require "rails_helper"

RSpec.describe Announcement do
  describe "validations" do
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_presence_of(:message) }
  end

  describe "associations" do
    it { is_expected.to have_many(:announcement_dismissals).dependent(:destroy) }
  end

  describe "indexes" do
    it "has an index on grant_code" do
      index = ActiveRecord::Base.connection.indexes(:announcements).find { |i| i.columns == [ "grant_code" ] }

      expect(index).to be_present
    end
  end
end
