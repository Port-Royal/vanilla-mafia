# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsPolicy do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:editor) { create(:user, :editor) }
  let_it_be(:regular_user) { create(:user) }

  let(:published_news) { build(:news, :published) }
  let(:draft_news) { build(:news) }

  describe "admin" do
    subject(:policy) { described_class.new(admin, published_news) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_new }
    it { is_expected.to be_update }
    it { is_expected.to be_edit }
    it { is_expected.to be_destroy }

    context "with draft news" do
      subject(:policy) { described_class.new(admin, draft_news) }

      it { is_expected.to be_show }
    end
  end

  describe "editor" do
    subject(:policy) { described_class.new(editor, published_news) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_new }
    it { is_expected.to be_update }
    it { is_expected.to be_edit }
    it { is_expected.not_to be_destroy }

    context "with draft news" do
      subject(:policy) { described_class.new(editor, draft_news) }

      it { is_expected.to be_show }
    end
  end

  describe "regular user" do
    subject(:policy) { described_class.new(regular_user, published_news) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_new }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_destroy }

    context "with draft news" do
      subject(:policy) { described_class.new(regular_user, draft_news) }

      it { is_expected.not_to be_show }
    end
  end

  describe NewsPolicy::Scope do
    let_it_be(:published) { create(:news, :published) }
    let_it_be(:draft) { create(:news) }

    context "when admin" do
      subject(:resolved) { described_class.new(admin, News).resolve }

      it "returns all news" do
        expect(resolved).to include(published, draft)
      end
    end

    context "when editor" do
      subject(:resolved) { described_class.new(editor, News).resolve }

      it "returns all news" do
        expect(resolved).to include(published, draft)
      end
    end

    context "when regular user" do
      subject(:resolved) { described_class.new(regular_user, News).resolve }

      it "includes published news" do
        expect(resolved).to include(published)
      end

      it "excludes draft news" do
        expect(resolved).not_to include(draft)
      end
    end
  end
end
