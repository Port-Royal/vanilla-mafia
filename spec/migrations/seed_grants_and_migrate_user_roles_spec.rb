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

    context "when users have roles" do
      let!(:admin_user) { create(:user, :admin) }
      let!(:judge_user) { create(:user, :judge) }
      let!(:regular_user) { create(:user) }

      it "creates user_grants matching each user's current role" do
        described_class.new.up

        expect(grant_code_for(admin_user)).to eq("admin")
        expect(grant_code_for(judge_user)).to eq("judge")
        expect(grant_code_for(regular_user)).to eq("user")
      end

      def grant_code_for(user)
        UserGrant.joins(:grant).where(user: user).pick("grants.code")
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
