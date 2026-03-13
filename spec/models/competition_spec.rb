require 'rails_helper'

RSpec.describe Competition, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:parent).class_name("Competition").optional }
    it { is_expected.to have_many(:children).class_name("Competition").with_foreign_key(:parent_id).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:competition) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(Competition::KINDS) }
    it 'validates uniqueness of slug' do
      create(:competition, slug: "taken")
      competition = build(:competition, slug: "taken")
      expect(competition).not_to be_valid
      expect(competition.errors[:slug]).to be_present
    end

    context 'when name and slug are both blank' do
      subject { build(:competition, name: nil, slug: nil) }

      it 'is invalid due to blank slug' do
        expect(subject).not_to be_valid
        expect(subject.errors[:slug]).to be_present
      end
    end
  end

  describe '.featured' do
    let_it_be(:featured) { create(:competition, :featured) }
    let_it_be(:regular) { create(:competition) }

    it 'returns only featured competitions' do
      expect(described_class.featured).to include(featured)
      expect(described_class.featured).not_to include(regular)
    end
  end

  describe '.ordered' do
    let_it_be(:second) { create(:competition, position: 2) }
    let_it_be(:first) { create(:competition, position: 1) }
    let_it_be(:no_position) { create(:competition, position: nil) }

    it 'orders by position ascending with nulls first, then by id' do
      expect(described_class.ordered).to eq([ no_position, first, second ])
    end
  end

  describe '.roots' do
    let_it_be(:root) { create(:competition) }
    let_it_be(:child) { create(:competition, :with_parent) }

    it 'returns competitions without a parent' do
      expect(described_class.roots).to include(root)
      expect(described_class.roots).not_to include(child)
    end
  end

  describe '.by_kind' do
    let_it_be(:season) { create(:competition, :season) }
    let_it_be(:series) { create(:competition, :series) }

    it 'returns competitions of the given kind' do
      expect(described_class.by_kind("season")).to include(season)
      expect(described_class.by_kind("season")).not_to include(series)
    end
  end

  describe '#generate_slug' do
    it 'generates a slug from the name when slug is blank' do
      competition = build(:competition, name: "Season One", slug: nil)
      competition.valid?
      expect(competition.slug).to eq("season-one")
    end

    it 'does not overwrite an existing slug' do
      competition = build(:competition, name: "Season One", slug: "custom-slug")
      competition.valid?
      expect(competition.slug).to eq("custom-slug")
    end
  end

  describe 'parent-child relationship' do
    let_it_be(:parent) { create(:competition, :season) }
    let_it_be(:child) { create(:competition, :series, parent: parent) }

    it 'links parent to children' do
      expect(parent.children).to include(child)
    end

    it 'links child to parent' do
      expect(child.parent).to eq(parent)
    end
  end
end
