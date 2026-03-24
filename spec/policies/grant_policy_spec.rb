# frozen_string_literal: true

require "rails_helper"

RSpec.describe GrantPolicy do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }
  let(:record) { Grant.find_or_create_by!(code: "admin") }

  describe "admin user" do
    subject(:policy) { described_class.new(admin, record) }

    it { is_expected.to be_index }
    it { is_expected.to be_show }
    it "returns false for create" do
      expect(policy.create?).to be false
    end

    it { is_expected.not_to be_new }

    it "returns false for update" do
      expect(policy.update?).to be false
    end

    it { is_expected.not_to be_edit }

    it "returns false for destroy" do
      expect(policy.destroy?).to be false
    end
  end

  describe "non-admin user" do
    subject(:policy) { described_class.new(user, record) }

    it { is_expected.not_to be_index }
    it { is_expected.not_to be_show }

    it "returns false for create" do
      expect(policy.create?).to be false
    end

    it { is_expected.not_to be_new }

    it "returns false for update" do
      expect(policy.update?).to be false
    end

    it { is_expected.not_to be_edit }

    it "returns false for destroy" do
      expect(policy.destroy?).to be false
    end
  end
end
