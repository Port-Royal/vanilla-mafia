# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPolicy do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user, admin: false) }
  let(:record) { User }

  describe "admin user" do
    subject(:policy) { described_class.new(admin, record) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it { is_expected.to be_create }
    it { is_expected.to be_new }
    it { is_expected.to be_update }
    it { is_expected.to be_edit }
    it { is_expected.to be_destroy }
  end

  describe "non-admin user" do
    subject(:policy) { described_class.new(user, record) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_new }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_destroy }
  end

  describe "nil user" do
    subject(:policy) { described_class.new(nil, record) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }
    it { is_expected.not_to be_create }
    it { is_expected.not_to be_new }
    it { is_expected.not_to be_update }
    it { is_expected.not_to be_edit }
    it { is_expected.not_to be_destroy }
  end

  describe ApplicationPolicy::Scope do
    let_it_be(:existing_user) { create(:user) }

    describe "admin user" do
      subject(:resolved) { described_class.new(admin, User).resolve }

      it "returns all records" do
        expect(resolved).to include(existing_user)
      end
    end

    describe "non-admin user" do
      subject(:resolved) { described_class.new(user, User).resolve }

      it "returns no records" do
        expect(resolved).to be_empty
      end
    end

    describe "nil user" do
      subject(:resolved) { described_class.new(nil, User).resolve }

      it "returns no records" do
        expect(resolved).to be_empty
      end
    end
  end
end
