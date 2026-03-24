require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:player).optional }
    it { is_expected.to have_many(:player_claims).dependent(:destroy) }
    it { is_expected.to have_many(:user_grants).dependent(:destroy) }
    it { is_expected.to have_many(:grants).through(:user_grants) }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_inclusion_of(:locale).in_array(%w[ru en]) }
    it { is_expected.to validate_presence_of(:role) }

    describe "player_id uniqueness" do
      let(:player) { create(:player) }

      it "allows nil player_id" do
        user = build(:user, player_id: nil)
        expect(user).to be_valid
      end

      it "rejects duplicate player_id" do
        create(:user, player: player)
        user = build(:user, player: player)
        expect(user).not_to be_valid
        expect(user.errors.where(:player_id, :taken)).to be_present
      end
    end
  end

  describe "role enum" do
    it "defines user, judge, editor, and admin roles" do
      expect(described_class.roles).to eq("user" => "user", "judge" => "judge", "editor" => "editor", "admin" => "admin")
    end

    it "defaults to user role" do
      user = build(:user)
      expect(user.role).to eq("user")
    end
  end

  describe "#has_grant?" do
    let(:user) { create(:user) }
    let(:admin_grant) { Grant.find_or_create_by!(code: "admin") }
    let(:judge_grant) { Grant.find_or_create_by!(code: "judge") }

    context "when user has the grant" do
      before { create(:user_grant, user: user, grant: admin_grant) }

      it "returns true" do
        expect(user.has_grant?("admin")).to be true
      end
    end

    context "when user does not have the grant" do
      it "returns false" do
        expect(user.has_grant?("admin")).to be false
      end
    end

    context "when user has a different grant" do
      before { create(:user_grant, user: user, grant: judge_grant) }

      it "returns false for unassigned grant" do
        expect(user.has_grant?("admin")).to be false
      end

      it "returns true for assigned grant" do
        expect(user.has_grant?("judge")).to be true
      end
    end
  end

  describe "#admin?" do
    context "when role is admin" do
      let(:user) { build(:user, :admin) }

      it "returns true" do
        expect(user.admin?).to be true
      end
    end

    context "when role is user" do
      let(:user) { build(:user) }

      it "returns false" do
        expect(user.admin?).to be false
      end
    end

    context "when role is judge" do
      let(:user) { build(:user, :judge) }

      it "returns false" do
        expect(user.admin?).to be false
      end
    end
  end

  describe "#judge?" do
    context "when role is judge" do
      let(:user) { build(:user, :judge) }

      it "returns true" do
        expect(user.judge?).to be true
      end
    end

    context "when role is user" do
      let(:user) { build(:user) }

      it "returns false" do
        expect(user.judge?).to be false
      end
    end

    context "when role is admin" do
      let(:user) { build(:user, :admin) }

      it "returns false" do
        expect(user.judge?).to be false
      end
    end
  end

  describe "#can_manage_protocols?" do
    context "when role is admin" do
      let(:user) { build(:user, :admin) }

      it "returns true" do
        expect(user.can_manage_protocols?).to be true
      end
    end

    context "when role is judge" do
      let(:user) { build(:user, :judge) }

      it "returns true" do
        expect(user.can_manage_protocols?).to be true
      end
    end

    context "when role is user" do
      let(:user) { build(:user) }

      it "returns false" do
        expect(user.can_manage_protocols?).to be false
      end
    end

    context "when role is editor" do
      let(:user) { build(:user, :editor) }

      it "returns false" do
        expect(user.can_manage_protocols?).to be false
      end
    end
  end

  describe "#can_manage_news?" do
    context "when role is admin" do
      let(:user) { build(:user, :admin) }

      it "returns true" do
        expect(user.can_manage_news?).to be true
      end
    end

    context "when role is editor" do
      let(:user) { build(:user, :editor) }

      it "returns true" do
        expect(user.can_manage_news?).to be true
      end
    end

    context "when role is user" do
      let(:user) { build(:user) }

      it "returns false" do
        expect(user.can_manage_news?).to be false
      end
    end

    context "when role is judge" do
      let(:user) { build(:user, :judge) }

      it "returns false" do
        expect(user.can_manage_news?).to be false
      end
    end
  end

  describe "#claimed_player?" do
    context "when user has a claimed player" do
      let(:player) { create(:player) }
      let(:user) { create(:user, player: player) }

      it "returns true" do
        expect(user.claimed_player?).to be true
      end
    end

    context "when user has no claimed player" do
      let(:user) { build(:user) }

      it "returns false" do
        expect(user.claimed_player?).to be false
      end
    end
  end

  describe "#pending_claim?" do
    context "when user has a pending claim" do
      let(:user) { create(:user) }

      before { create(:player_claim, user: user, status: "pending") }

      it "returns true" do
        expect(user.pending_claim?).to be true
      end
    end

    context "when user has no pending claim" do
      let(:user) { create(:user) }

      it "returns false" do
        expect(user.pending_claim?).to be false
      end
    end

    context "when user has only non-pending claims" do
      let(:user) { create(:user) }

      before { create(:player_claim, user: user, status: "rejected") }

      it "returns false" do
        expect(user.pending_claim?).to be false
      end
    end
  end

  describe "#pending_dispute?" do
    let(:player) { create(:player) }
    let!(:owner) { create(:user, player: player) }
    let(:user) { create(:user) }

    context "when user has a pending dispute claim" do
      before { create(:player_claim, :dispute, user: user, player: player) }

      it "returns true" do
        expect(user.pending_dispute?).to be true
      end
    end

    context "when user has no pending dispute" do
      it "returns false" do
        expect(user.pending_dispute?).to be false
      end
    end

    context "when user has only non-pending dispute claims" do
      before { create(:player_claim, :dispute, user: user, player: player, status: "rejected") }

      it "returns false" do
        expect(user.pending_dispute?).to be false
      end
    end
  end

  describe "#pending_claim_for" do
    let(:user) { create(:user) }
    let(:player) { create(:player) }

    context "when user has a pending claim for the player" do
      let!(:claim) { create(:player_claim, user: user, player: player, status: "pending") }

      it "returns the claim" do
        expect(user.pending_claim_for(player)).to eq(claim)
      end
    end

    context "when user has no pending claim for the player" do
      it "returns nil" do
        expect(user.pending_claim_for(player)).to be_nil
      end
    end

    context "when user has a non-pending claim for the player" do
      before { create(:player_claim, user: user, player: player, status: "approved") }

      it "returns nil" do
        expect(user.pending_claim_for(player)).to be_nil
      end
    end
  end
end
