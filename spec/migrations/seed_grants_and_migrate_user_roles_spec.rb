require "rails_helper"
require_relative "../../db/migrate/20260324065136_seed_grants_and_migrate_user_roles"

RSpec.describe SeedGrantsAndMigrateUserRoles do
  describe "#up" do
    context "when grants table is empty" do
      it "seeds all grant codes" do
        described_class.new.up

        expect(Grant.pluck(:code)).to contain_exactly("user", "judge", "editor", "admin")
      end
    end
  end

  describe "#down" do
    it "removes all user_grants and grants" do
      described_class.new.up

      described_class.new.down

      expect(Grant.count).to eq(0)
      expect(UserGrant.count).to eq(0)
    end
  end
end
