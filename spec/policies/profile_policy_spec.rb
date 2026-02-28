# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProfilePolicy do
  let_it_be(:player) { create(:player) }

  describe "#edit?" do
    context "when user owns the player" do
      subject(:policy) { described_class.new(user, player) }

      let(:user) { double("User", player_id: player.id) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.to be_edit }
    end

    context "when user does not own the player" do
      subject(:policy) { described_class.new(user, player) }

      let(:other_player) { create(:player) }
      let(:user) { double("User", player_id: other_player.id) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.not_to be_edit }
    end

    context "when user has no player" do
      subject(:policy) { described_class.new(user, player) }

      let(:user) { double("User", player_id: nil) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.not_to be_edit }
    end

    context "when user is nil" do
      subject(:policy) { described_class.new(nil, player) }

      it { is_expected.not_to be_edit }
    end
  end

  describe "#update?" do
    context "when user owns the player" do
      subject(:policy) { described_class.new(user, player) }

      let(:user) { double("User", player_id: player.id) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.to be_update }
    end

    context "when user does not own the player" do
      subject(:policy) { described_class.new(user, player) }

      let(:other_player) { create(:player) }
      let(:user) { double("User", player_id: other_player.id) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.not_to be_update }
    end

    context "when user has no player" do
      subject(:policy) { described_class.new(user, player) }

      let(:user) { double("User", player_id: nil) } # rubocop:disable RSpec/VerifiedDoubles

      it { is_expected.not_to be_update }
    end

    context "when user is nil" do
      subject(:policy) { described_class.new(user, player) }

      let(:user) { nil }

      it { is_expected.not_to be_edit }
      it { is_expected.not_to be_update }
    end
  end
end
