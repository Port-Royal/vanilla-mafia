require "rails_helper"

RSpec.describe TelegramAuthor, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user).optional }
  end

  describe "validations" do
    subject { build(:telegram_author) }

    it { is_expected.to validate_presence_of(:telegram_user_id) }
    it { is_expected.to validate_uniqueness_of(:telegram_user_id) }
    it { is_expected.to validate_numericality_of(:telegram_user_id).only_integer }
  end

  describe ".whitelisted?" do
    let_it_be(:author) { create(:telegram_author, telegram_user_id: 42) }

    it "returns true for a whitelisted telegram_user_id" do
      expect(described_class).to be_whitelisted(42)
    end

    it "returns false for an unknown telegram_user_id" do
      expect(described_class).not_to be_whitelisted(999)
    end
  end

  describe ".find_by_telegram_id" do
    let_it_be(:author) { create(:telegram_author, telegram_user_id: 42, telegram_username: "testuser") }

    it "returns the author for a known telegram_user_id" do
      expect(described_class.find_by_telegram_id(42)).to eq(author)
    end

    it "returns nil for an unknown telegram_user_id" do
      expect(described_class.find_by_telegram_id(999)).to be_nil
    end
  end
end
