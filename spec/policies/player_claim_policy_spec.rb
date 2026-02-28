# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlayerClaimPolicy do
  let(:record) { :player_claim }

  describe "#create?" do
    subject(:policy) { described_class.new(user, record) }

    context "when user has no claimed player and no pending claim" do
      let(:user) { double("User", claimed_player?: false, pending_claim?: false) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.to be_create }
    end

    context "when user already has a claimed player" do
      let(:user) { double("User", claimed_player?: true, pending_claim?: false) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.not_to be_create }
    end

    context "when user has a pending claim" do
      let(:user) { double("User", claimed_player?: false, pending_claim?: true) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.not_to be_create }
    end

    context "when user has both a claimed player and a pending claim" do
      let(:user) { double("User", claimed_player?: true, pending_claim?: true) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.not_to be_create }
    end

    context "with a real user record" do
      let(:user) { create(:user) }

      it { is_expected.to be_create }
    end

    context "when user is nil" do
      let(:user) { nil }

      it { is_expected.not_to be_create }
    end
  end

  describe "#index?" do
    context "when user is admin" do
      subject(:policy) { described_class.new(admin, record) }

      let_it_be(:admin) { create(:user, admin: true) }

      it { is_expected.to be_index }
    end

    context "when user is not admin" do
      subject(:policy) { described_class.new(user, record) }

      let_it_be(:user) { create(:user, admin: false) }

      it { is_expected.not_to be_index }
    end
  end

  describe "#show?" do
    context "when user is admin" do
      subject(:policy) { described_class.new(admin, record) }

      let_it_be(:admin) { create(:user, admin: true) }

      it { is_expected.to be_show }
    end

    context "when user is not admin" do
      subject(:policy) { described_class.new(user, record) }

      let_it_be(:user) { create(:user, admin: false) }

      it { is_expected.not_to be_show }
    end
  end

  describe "#update?" do
    context "when user is admin" do
      subject(:policy) { described_class.new(admin, record) }

      let_it_be(:admin) { create(:user, admin: true) }

      it { is_expected.to be_update }
    end

    context "when user is not admin" do
      subject(:policy) { described_class.new(user, record) }

      let_it_be(:user) { create(:user, admin: false) }

      it { is_expected.not_to be_update }
    end
  end

  describe "#destroy?" do
    context "when user is admin" do
      subject(:policy) { described_class.new(admin, record) }

      let_it_be(:admin) { create(:user, admin: true) }

      it { is_expected.to be_destroy }
    end

    context "when user is not admin" do
      subject(:policy) { described_class.new(user, record) }

      let_it_be(:user) { create(:user, admin: false) }

      it { is_expected.not_to be_destroy }
    end
  end
end
