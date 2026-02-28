require "rails_helper"

RSpec.describe HallOfFameService do
  describe ".call" do
    let_it_be(:player1) { create(:player, name: "Алексей") }
    let_it_be(:player2) { create(:player, name: "Борис") }
    let_it_be(:organizer1) { create(:player, name: "Ведущий") }
    let_it_be(:organizer2) { create(:player, name: "Главный") }
    let_it_be(:player_award_type) { create(:award, title: "Лучший игрок", staff: false) }
    let_it_be(:staff_award_type) { create(:award, title: "Лучший ведущий", staff: true) }
    let_it_be(:player_award2) { create(:player_award, player: player2, award: player_award_type, season: 5, position: 2) }
    let_it_be(:player_award1) { create(:player_award, player: player1, award: player_award_type, season: 4, position: 1) }
    let_it_be(:staff_award2) { create(:player_award, player: organizer2, award: staff_award_type, season: 5, position: 2) }
    let_it_be(:staff_award1) { create(:player_award, player: organizer1, award: staff_award_type, season: 4, position: 1) }
    let(:result) { described_class.call }

    it "returns a Result" do
      expect(result).to be_a(described_class::Result)
    end

    it "returns player awards grouped by player" do
      expect(result.player_awards).to eq(player1 => [ player_award1 ], player2 => [ player_award2 ])
    end

    it "returns staff awards grouped by player" do
      expect(result.staff_awards).to eq(organizer1 => [ staff_award1 ], organizer2 => [ staff_award2 ])
    end

    it "does not include staff awards in player awards" do
      expect(result.player_awards.keys).not_to include(organizer1)
    end

    it "does not include player awards in staff awards" do
      expect(result.staff_awards.keys).not_to include(player1)
    end

    it "eager loads player association on player awards" do
      expect(result.player_awards.values.first.first.association(:player)).to be_loaded
    end

    it "eager loads award association on player awards" do
      expect(result.player_awards.values.first.first.association(:award)).to be_loaded
    end

    it "eager loads player association on staff awards" do
      expect(result.staff_awards.values.first.first.association(:player)).to be_loaded
    end

    it "eager loads award association on staff awards" do
      expect(result.staff_awards.values.first.first.association(:award)).to be_loaded
    end

    context "when no awards exist" do
      let(:empty_result) { described_class.call }

      before do
        PlayerAward.destroy_all
      end

      it "returns empty player_awards" do
        expect(empty_result.player_awards).to be_empty
      end

      it "returns empty staff_awards" do
        expect(empty_result.staff_awards).to be_empty
      end
    end
  end
end
