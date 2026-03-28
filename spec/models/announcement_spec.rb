# frozen_string_literal: true

require "rails_helper"

RSpec.describe Announcement do
  describe "validations" do
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_presence_of(:message_ru) }
    it { is_expected.to validate_presence_of(:message_en) }
  end

  describe "associations" do
    it { is_expected.to have_many(:announcement_dismissals).dependent(:destroy) }
  end

  describe "#localized_message" do
    let(:announcement) { create(:announcement, message_ru: "Русский текст", message_en: "English text") }

    context "when locale is :ru" do
      it "returns the Russian message" do
        I18n.with_locale(:ru) do
          expect(announcement.localized_message).to eq("Русский текст")
        end
      end
    end

    context "when locale is :en" do
      it "returns the English message" do
        I18n.with_locale(:en) do
          expect(announcement.localized_message).to eq("English text")
        end
      end
    end
  end

  describe "indexes" do
    it "has an index on grant_code" do
      index = ActiveRecord::Base.connection.indexes(:announcements).find { |i| i.columns == [ "grant_code" ] }

      expect(index).to be_present
    end
  end
end
