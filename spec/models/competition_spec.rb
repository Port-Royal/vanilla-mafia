require 'rails_helper'

RSpec.describe Competition, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:parent).class_name("Competition").optional }
    it { is_expected.to have_many(:children).class_name("Competition").with_foreign_key(:parent_id).dependent(:destroy) }
    it { is_expected.to have_many(:games).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { build(:competition) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to define_enum_for(:kind).with_values(Competition::KINDS).backed_by_column_of_type(:string).without_scopes }
    it 'validates uniqueness of slug' do
      create(:competition, slug: "taken")
      competition = build(:competition, slug: "taken")
      expect(competition).not_to be_valid
      expect(competition.errors[:slug]).to be_present
    end

    context 'when name and slug are both blank' do
      subject { build(:competition, name: nil, slug: nil) }

      it 'is invalid due to blank name and slug' do
        expect(subject).not_to be_valid
        expect(subject.errors[:name]).to be_present
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

  describe '#parent_is_not_self' do
    it 'is invalid when parent_id equals own id' do
      competition = create(:competition)
      competition.parent_id = competition.id
      expect(competition).not_to be_valid
      expect(competition.errors[:parent_id]).to include("cannot reference itself")
    end

    it 'is valid when parent_id differs from own id' do
      parent = create(:competition)
      competition = create(:competition, parent: parent)
      expect(competition).to be_valid
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
