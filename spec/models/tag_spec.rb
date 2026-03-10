require "rails_helper"

RSpec.describe Tag, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:taggings).dependent(:destroy) }
  end

  describe "validations" do
    subject { create(:tag) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_uniqueness_of(:slug) }
  end

  describe "slug generation" do
    context "when slug is blank" do
      let(:tag) { build(:tag, name: "Турнир Весна", slug: nil) }

      it "generates slug from name" do
        tag.valid?
        expect(tag.slug).to eq("turnir-vesna")
      end
    end

    context "when slug is provided" do
      let(:tag) { build(:tag, name: "Test", slug: "custom-slug") }

      it "preserves the provided slug" do
        tag.valid?
        expect(tag.slug).to eq("custom-slug")
      end
    end
  end

  describe "scopes" do
    describe ".ordered" do
      let_it_be(:tag_b) { create(:tag, name: "Bravo") }
      let_it_be(:tag_a) { create(:tag, name: "Alpha") }

      it "orders by name" do
        expect(described_class.ordered).to eq([ tag_a, tag_b ])
      end
    end
  end
end
