require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:player).optional }
    it { is_expected.to have_many(:player_claims).dependent(:destroy) }
    it { is_expected.to have_many(:user_grants).dependent(:destroy) }
    it { is_expected.to have_many(:grants).through(:user_grants) }
  end

  describe "devise modules" do
    it "includes omniauthable" do
      expect(User.devise_modules).to include(:omniauthable)
    end

    it "configures google_oauth2 as omniauth provider" do
      expect(User.omniauth_providers).to include(:google_oauth2)
    end

    it "includes lockable" do
      expect(User.devise_modules).to include(:lockable)
    end

    it "includes timeoutable" do
      expect(User.devise_modules).to include(:timeoutable)
    end

    it "configures timeout_in to 2 weeks" do
      expect(Devise.timeout_in).to eq(2.weeks)
    end
  end

  describe "database columns" do
    it { is_expected.to have_db_column(:provider).of_type(:string) }
    it { is_expected.to have_db_column(:uid).of_type(:string) }
    it { is_expected.to have_db_index(%i[provider uid]).unique }
    it { is_expected.to have_db_column(:failed_attempts).of_type(:integer).with_options(default: 0, null: false) }
    it { is_expected.to have_db_column(:unlock_token).of_type(:string) }
    it { is_expected.to have_db_column(:locked_at).of_type(:datetime) }
    it { is_expected.to have_db_index(:unlock_token).unique }
  end

  describe "lockable behavior" do
    let(:user) { create(:user) }

    it "locks the account after 5 failed attempts" do
      5.times { user.valid_for_authentication? { false } }
      expect(user.reload.access_locked?).to be true
    end

    it "does not lock after 4 failed attempts" do
      4.times { user.valid_for_authentication? { false } }
      expect(user.reload.access_locked?).to be false
    end

    it "auto-unlocks after the configured unlock_in window has passed" do
      5.times { user.valid_for_authentication? { false } }
      user.update!(locked_at: 16.minutes.ago)
      expect(user.access_locked?).to be false
    end

    it "stays locked while still inside the unlock_in window" do
      5.times { user.valid_for_authentication? { false } }
      user.update!(locked_at: 14.minutes.ago)
      expect(user.access_locked?).to be true
    end

    it "generates an unlock token when locking via :both unlock strategy" do
      5.times { user.valid_for_authentication? { false } }
      expect(user.reload.unlock_token).to be_present
    end
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_inclusion_of(:locale).in_array(%w[ru en]) }


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

  describe "#display_name" do
    context "when user has no claimed player" do
      let(:user) { create(:user) }

      it "returns email" do
        expect(user.display_name).to eq(user.email)
      end
    end

    context "when user has a claimed player" do
      let(:player) { create(:player, name: "TestPlayer") }
      let(:user) { create(:user, player: player) }

      it "returns email with player name" do
        expect(user.display_name).to eq("#{user.email} (TestPlayer)")
      end
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
    let(:user) { create(:user) }
    let(:admin_grant) { Grant.find_or_create_by!(code: "admin") }

    context "when user has admin grant" do
      before { create(:user_grant, user: user, grant: admin_grant) }

      it "returns true" do
        expect(user.admin?).to be true
      end
    end

    context "when user has no admin grant" do
      it "returns false" do
        expect(user.admin?).to be false
      end
    end

    context "when user has a different grant" do
      let(:judge_grant) { Grant.find_or_create_by!(code: "judge") }

      before { create(:user_grant, user: user, grant: judge_grant) }

      it "returns false" do
        expect(user.admin?).to be false
      end
    end
  end

  describe "#judge?" do
    let(:user) { create(:user) }
    let(:judge_grant) { Grant.find_or_create_by!(code: "judge") }

    context "when user has judge grant" do
      before { create(:user_grant, user: user, grant: judge_grant) }

      it "returns true" do
        expect(user.judge?).to be true
      end
    end

    context "when user has no judge grant" do
      it "returns false" do
        expect(user.judge?).to be false
      end
    end

    context "when user has a different grant" do
      let(:admin_grant) { Grant.find_or_create_by!(code: "admin") }

      before { create(:user_grant, user: user, grant: admin_grant) }

      it "returns false" do
        expect(user.judge?).to be false
      end
    end
  end

  describe "#editor?" do
    let(:user) { create(:user) }
    let(:editor_grant) { Grant.find_or_create_by!(code: "editor") }

    context "when user has editor grant" do
      before { create(:user_grant, user: user, grant: editor_grant) }

      it "returns true" do
        expect(user.editor?).to be true
      end
    end

    context "when user has no editor grant" do
      it "returns false" do
        expect(user.editor?).to be false
      end
    end
  end

  describe "#subscriber?" do
    let(:user) { create(:user) }
    let(:subscriber_grant) { Grant.find_or_create_by!(code: "subscriber") }

    context "when user has subscriber grant" do
      before { create(:user_grant, user: user, grant: subscriber_grant) }

      it "returns true" do
        expect(user.subscriber?).to be true
      end
    end

    context "when user has no subscriber grant" do
      it "returns false" do
        expect(user.subscriber?).to be false
      end
    end
  end

  describe "#can_manage_protocols?" do
    let(:user) { create(:user) }

    context "when user has admin grant" do
      let(:admin_grant) { Grant.find_or_create_by!(code: "admin") }

      before { create(:user_grant, user: user, grant: admin_grant) }

      it "returns true" do
        expect(user.can_manage_protocols?).to be true
      end
    end

    context "when user has judge grant" do
      let(:judge_grant) { Grant.find_or_create_by!(code: "judge") }

      before { create(:user_grant, user: user, grant: judge_grant) }

      it "returns true" do
        expect(user.can_manage_protocols?).to be true
      end
    end

    context "when user has no grants" do
      it "returns false" do
        expect(user.can_manage_protocols?).to be false
      end
    end

    context "when user has editor grant" do
      let(:editor_grant) { Grant.find_or_create_by!(code: "editor") }

      before { create(:user_grant, user: user, grant: editor_grant) }

      it "returns false" do
        expect(user.can_manage_protocols?).to be false
      end
    end
  end

  describe "#can_manage_news?" do
    let(:user) { create(:user) }

    context "when user has admin grant" do
      let(:admin_grant) { Grant.find_or_create_by!(code: "admin") }

      before { create(:user_grant, user: user, grant: admin_grant) }

      it "returns true" do
        expect(user.can_manage_news?).to be true
      end
    end

    context "when user has editor grant" do
      let(:editor_grant) { Grant.find_or_create_by!(code: "editor") }

      before { create(:user_grant, user: user, grant: editor_grant) }

      it "returns true" do
        expect(user.can_manage_news?).to be true
      end
    end

    context "when user has no grants" do
      it "returns false" do
        expect(user.can_manage_news?).to be false
      end
    end

    context "when user has judge grant" do
      let(:judge_grant) { Grant.find_or_create_by!(code: "judge") }

      before { create(:user_grant, user: user, grant: judge_grant) }

      it "returns false" do
        expect(user.can_manage_news?).to be false
      end
    end
  end

  describe "#can_view_help?" do
    let(:user) { create(:user) }

    context "when user has admin grant" do
      let(:admin_grant) { Grant.find_or_create_by!(code: "admin") }

      before { create(:user_grant, user: user, grant: admin_grant) }

      it "returns true" do
        expect(user.can_view_help?).to be true
      end
    end

    context "when user has judge grant" do
      let(:judge_grant) { Grant.find_or_create_by!(code: "judge") }

      before { create(:user_grant, user: user, grant: judge_grant) }

      it "returns true" do
        expect(user.can_view_help?).to be true
      end
    end

    context "when user has no grants" do
      it "returns false" do
        expect(user.can_view_help?).to be false
      end
    end

    context "when user has editor grant" do
      let(:editor_grant) { Grant.find_or_create_by!(code: "editor") }

      before { create(:user_grant, user: user, grant: editor_grant) }

      it "returns false" do
        expect(user.can_view_help?).to be false
      end
    end

    context "when user has subscriber grant" do
      let(:subscriber_grant) { Grant.find_or_create_by!(code: "subscriber") }

      before { create(:user_grant, user: user, grant: subscriber_grant) }

      it "returns false" do
        expect(user.can_view_help?).to be false
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

    context "when user has a pending non-dispute claim" do
      let(:other_player) { create(:player) }

      before { create(:player_claim, user: user, player: other_player, status: "pending") }

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
