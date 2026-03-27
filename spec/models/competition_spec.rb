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

  describe '.running' do
    let_it_be(:running) { create(:competition, ended_on: nil) }
    let_it_be(:finished) { create(:competition, ended_on: Date.new(2025, 12, 31)) }

    it 'returns competitions without an ended_on date' do
      expect(described_class.running).to include(running)
    end

    it 'excludes finished competitions' do
      expect(described_class.running).not_to include(finished)
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

  describe '#to_param' do
    let_it_be(:competition) { create(:competition, slug: "season-5") }

    it 'returns the slug' do
      expect(competition.to_param).to eq("season-5")
    end
  end

  describe '#root' do
    context 'when competition has no parent' do
      let_it_be(:competition) { create(:competition, :season) }

      it 'returns itself' do
        expect(competition.root).to eq(competition)
      end
    end

    context 'when competition has a parent' do
      let_it_be(:parent) { create(:competition, :season) }
      let_it_be(:child) { create(:competition, :series, parent: parent) }

      it 'returns the root ancestor' do
        expect(child.root).to eq(parent)
      end
    end

    context 'when competition has a grandparent' do
      let_it_be(:grandparent) { create(:competition, :season) }
      let_it_be(:parent) { create(:competition, :series, parent: grandparent) }
      let_it_be(:grandchild) { create(:competition, :round, parent: parent) }

      it 'returns the root ancestor' do
        expect(grandchild.root).to eq(grandparent)
      end
    end

    context 'when parent is eager-loaded' do
      let_it_be(:parent) { create(:competition, :season) }
      let_it_be(:child) { create(:competition, :series, parent: parent) }

      it 'uses the eager-loaded parent' do
        loaded = Competition.includes(:parent).find(child.id)
        expect(loaded.association(:parent)).to be_loaded
        expect(loaded.root).to eq(parent)
      end
    end
  end

  describe '#ancestors' do
    context 'when competition has no parent' do
      let_it_be(:competition) { create(:competition, :season) }

      it 'returns an empty array' do
        expect(competition.ancestors).to eq([])
      end
    end

    context 'when competition has a parent' do
      let_it_be(:parent) { create(:competition, :season) }
      let_it_be(:child) { create(:competition, :series, parent: parent) }

      it 'returns the parent in an array' do
        expect(child.ancestors).to eq([ parent ])
      end
    end

    context 'when competition has a grandparent' do
      let_it_be(:grandparent) { create(:competition, :season) }
      let_it_be(:parent) { create(:competition, :series, parent: grandparent) }
      let_it_be(:grandchild) { create(:competition, :round, parent: parent) }

      it 'returns ancestors from root to immediate parent' do
        expect(grandchild.ancestors).to eq([ grandparent, parent ])
      end
    end
  end

  describe '#subtree_ids' do
    context 'when competition has no children' do
      let_it_be(:leaf) { create(:competition) }

      it 'returns only its own id' do
        expect(leaf.subtree_ids).to eq([ leaf.id ])
      end
    end

    context 'when competition has children' do
      let_it_be(:root) { create(:competition, :season) }
      let_it_be(:child1) { create(:competition, :series, parent: root) }
      let_it_be(:child2) { create(:competition, :series, parent: root) }

      it 'returns its own id and all children ids' do
        expect(root.subtree_ids).to contain_exactly(root.id, child1.id, child2.id)
      end
    end

    context 'when competition has nested descendants' do
      let_it_be(:root) { create(:competition, :season) }
      let_it_be(:child) { create(:competition, :series, parent: root) }
      let_it_be(:grandchild) { create(:competition, :round, parent: child) }

      it 'returns all descendant ids recursively' do
        expect(root.subtree_ids).to contain_exactly(root.id, child.id, grandchild.id)
      end
    end
  end
end
