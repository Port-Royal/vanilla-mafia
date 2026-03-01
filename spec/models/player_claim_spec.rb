require 'rails_helper'

RSpec.describe PlayerClaim, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:reviewed_by).class_name("User").optional }
  end

  describe 'validations' do
    subject { build(:player_claim) }

    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }

    it {
      is_expected.to validate_uniqueness_of(:user_id).scoped_to(:player_id)
    }

    context 'when user already has a claimed player' do
      let(:player) { create(:player) }
      let(:user) { create(:user, player_id: player.id) }

      it 'is invalid' do
        claim = build(:player_claim, user: user)

        expect(claim).not_to be_valid
        expect(claim.errors[:user]).to include(I18n.t("errors.messages.already_claimed"))
      end
    end

    context 'when user does not have a claimed player' do
      let(:user) { create(:user) }

      it 'is valid' do
        claim = build(:player_claim, user: user)

        expect(claim).to be_valid
      end
    end

    context 'when player is already claimed by another user' do
      let(:player) { create(:player) }

      before { create(:user, player_id: player.id) }

      it 'is invalid' do
        claim = build(:player_claim, player: player)

        expect(claim).not_to be_valid
        expect(claim.errors[:player]).to include(I18n.t("errors.messages.already_claimed"))
      end
    end

    context 'when player is not claimed' do
      it 'is valid' do
        claim = build(:player_claim)

        expect(claim).to be_valid
      end
    end

    context 'when dispute' do
      context 'when evidence is blank' do
        let(:player) { create(:player) }
        let(:claim) { build(:player_claim, :dispute, player: player, evidence: nil) }

        before { create(:user, player_id: player.id) }

        it 'is invalid' do
          expect(claim).not_to be_valid
          expect(claim.errors[:evidence]).to include(I18n.t("errors.messages.blank"))
        end
      end

      context 'when evidence is present' do
        let(:player) { create(:player) }
        let(:claim) { build(:player_claim, :dispute, player: player) }

        before { create(:user, player_id: player.id) }

        it 'is valid' do
          expect(claim).to be_valid
        end
      end

      context 'when player is already claimed by another user' do
        let(:player) { create(:player) }
        let(:claim) { build(:player_claim, :dispute, player: player) }

        before { create(:user, player_id: player.id) }

        it 'is valid (skips player_not_already_claimed)' do
          expect(claim).to be_valid
        end
      end

      context 'when player is not claimed by anyone' do
        let(:player) { create(:player) }
        let(:claim) { build(:player_claim, :dispute, player: player) }

        it 'is invalid' do
          expect(claim).not_to be_valid
          expect(claim.errors[:player]).to include(I18n.t("errors.messages.not_claimed"))
        end
      end

      context 'when player is claimed' do
        let(:player) { create(:player) }
        let(:claim) { build(:player_claim, :dispute, player: player) }

        before { create(:user, player_id: player.id) }

        it 'is valid' do
          expect(claim).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    let_it_be(:pending_claim) { create(:player_claim, status: "pending") }
    let_it_be(:approved_claim) { create(:player_claim, status: "approved") }
    let_it_be(:rejected_claim) { create(:player_claim, status: "rejected") }

    describe '.pending' do
      it 'returns only pending claims' do
        expect(described_class.pending).to eq([ pending_claim ])
      end
    end

    describe '.approved' do
      it 'returns only approved claims' do
        expect(described_class.approved).to eq([ approved_claim ])
      end
    end

    describe '.disputes' do
      let_it_be(:claimed_player) { create(:player) }
      let_it_be(:claimer) { create(:user, player_id: claimed_player.id) }
      let_it_be(:dispute_claim) { create(:player_claim, :dispute, player: claimed_player) }

      it 'returns only disputes' do
        expect(described_class.disputes).to eq([ dispute_claim ])
      end
    end

    describe '.claims' do
      it 'returns only non-dispute claims' do
        expect(described_class.claims).to contain_exactly(pending_claim, approved_claim, rejected_claim)
      end
    end
  end

  describe '#pending?' do
    context 'when status is pending' do
      let(:claim) { build(:player_claim, status: "pending") }

      it 'returns true' do
        expect(claim.pending?).to be true
      end
    end

    context 'when status is not pending' do
      let(:claim) { build(:player_claim, status: "approved") }

      it 'returns false' do
        expect(claim.pending?).to be false
      end
    end
  end

  describe '#approved?' do
    context 'when status is approved' do
      let(:claim) { build(:player_claim, status: "approved") }

      it 'returns true' do
        expect(claim.approved?).to be true
      end
    end

    context 'when status is not approved' do
      let(:claim) { build(:player_claim, status: "pending") }

      it 'returns false' do
        expect(claim.approved?).to be false
      end
    end
  end

  describe '#rejected?' do
    context 'when status is rejected' do
      let(:claim) { build(:player_claim, status: "rejected") }

      it 'returns true' do
        expect(claim.rejected?).to be true
      end
    end

    context 'when status is not rejected' do
      let(:claim) { build(:player_claim, status: "pending") }

      it 'returns false' do
        expect(claim.rejected?).to be false
      end
    end
  end

  describe '.require_approval?' do
    context 'when toggle is enabled' do
      let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: true) }

      it 'returns true' do
        expect(described_class.require_approval?).to be true
      end
    end

    context 'when toggle is disabled' do
      let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: false) }

      it 'returns false' do
        expect(described_class.require_approval?).to be false
      end
    end

    context 'when toggle does not exist' do
      it 'returns false' do
        expect(described_class.require_approval?).to be false
      end
    end
  end
end
