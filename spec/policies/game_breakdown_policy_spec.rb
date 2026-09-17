# frozen_string_literal: true

require "rails_helper"

RSpec.describe GameBreakdownPolicy do
  subject(:policy) { described_class.new(user, GameBreakdown.new) }

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:user) { create(:user) }

  context "with an admin" do
    let(:user) { admin }

    it "allows browsing" do
      expect(policy.index?).to be(true)
    end

    it "allows reading one" do
      expect(policy.show?).to be(true)
    end

    it "allows editing the metadata" do
      expect(policy.update?).to be(true)
    end

    it "allows deleting" do
      expect(policy.destroy?).to be(true)
    end

    # A breakdown is created through the judge editor, which also builds its seats and the zero round.
    it "refuses creating" do
      expect(policy.create?).to be(false)
    end

    it "refuses the new form" do
      expect(policy.new?).to be(false)
    end
  end

  context "with a regular user" do
    it "refuses browsing" do
      expect(policy.index?).to be(false)
    end

    it "refuses reading one" do
      expect(policy.show?).to be(false)
    end

    it "refuses deleting" do
      expect(policy.destroy?).to be(false)
    end
  end
end
