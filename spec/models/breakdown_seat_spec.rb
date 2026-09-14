require "rails_helper"

RSpec.describe BreakdownSeat, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:game_breakdown) }
    it { is_expected.to belong_to(:player).optional }
    it { is_expected.to belong_to(:role).with_foreign_key(:role_code).with_primary_key(:code).optional }
  end

  describe "validations" do
    subject { build(:breakdown_seat) }

    it { is_expected.to validate_uniqueness_of(:number).scoped_to(:game_breakdown_id) }
    it { is_expected.to validate_numericality_of(:number).only_integer.is_in(1..10) }
  end

  describe "normalization" do
    it "turns a blank name into nil" do
      expect(described_class.new(name: " ").name).to be_nil
    end

    it "strips the name" do
      expect(described_class.new(name: " Кот ").name).to eq("Кот")
    end

    it "turns a blank role code into nil" do
      expect(described_class.new(role_code: "").role_code).to be_nil
    end
  end
end
