require "rails_helper"

RSpec.describe Document do
  describe "validations" do
    subject { create(:document) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_uniqueness_of(:slug).ignoring_case_sensitivity }
    it { is_expected.to allow_value("league-rules", "rules2", "a").for(:slug) }
    it { is_expected.not_to allow_value("league rules", "правила", "-rules", "rules-", "a--b", "a/b", "a_b").for(:slug) }
    it { is_expected.not_to allow_value("new", "edit").for(:slug) }
  end

  describe "slug" do
    context "when left blank" do
      let(:document) { create(:document, title: "Регламент лиги") }

      it { expect(document.slug).to eq("reglament-ligi") }
    end

    context "when given" do
      let(:document) { create(:document, title: "Регламент лиги", slug: "league-rules") }

      it { expect(document.slug).to eq("league-rules") }
    end

    context "when typed with capitals and spaces around it" do
      let(:document) { create(:document, title: "Rules", slug: "  League-Rules ") }

      it { expect(document.slug).to eq("league-rules") }
    end

    context "when the title has underscores" do
      let(:document) { create(:document, title: "Rules_v2") }

      it { expect(document.slug).to eq("rules-v2") }
    end

    context "when the title has underscores at its ends and in a row" do
      let(:document) { create(:document, title: "__Rules__v2__") }

      it { expect(document.slug).to eq("rules-v2") }
    end

    context "when the title is only underscores" do
      let(:document) { create(:document, title: "___") }

      it { expect(document.slug).to match(/\A\h{4}\z/) }
    end

    context "when the title gives a slug Avo keeps for its own pages" do
      let(:document) { create(:document, title: "New") }

      it { expect(document.slug).to eq("new-document") }
    end

    context "when the title gives a taken slug" do
      let_it_be(:taken) { create(:document, title: "Rules") }
      let(:document) { create(:document, title: "Rules") }

      it { expect(document.slug).to match(/\Arules-\h{4}\z/) }
    end
  end

  describe "#to_param" do
    let(:document) { build(:document, slug: "game-rules") }

    it { expect(document.to_param).to eq("game-rules") }
  end

  describe "defaults" do
    let(:document) { described_class.new }

    it { expect(document.published).to be(false) }
    it { expect(document.position).to eq(0) }
  end

  describe "body" do
    let(:document) { create(:document, body: "<p>Text</p>") }

    it { expect(document.reload.body.to_plain_text).to eq("Text") }
  end

  describe ".published" do
    let_it_be(:draft) { create(:document) }
    let_it_be(:published) { create(:document, :published) }

    it { expect(described_class.published).to contain_exactly(published) }
  end

  describe ".ordered" do
    let_it_be(:third) { create(:document, position: 2) }
    let_it_be(:first) { create(:document, position: 1) }
    let_it_be(:second) { create(:document, position: 1) }

    it { expect(described_class.ordered).to eq([ first, second, third ]) }
    it { expect(described_class.ordered.reverse_order).to eq([ third, second, first ]) }
  end
end
