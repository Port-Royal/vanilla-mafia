require "rails_helper"

RSpec.describe HallOfFameService do
  describe ".call" do
    let!(:player1) { create(:player, name: "Алексей") }
    let!(:player2) { create(:player, name: "Борис") }
    let!(:organizer1) { create(:player, name: "Ведущий") }
    let!(:organizer2) { create(:player, name: "Главный") }
    let!(:player_award_type) { create(:award, title: "Лучший игрок", staff: false) }
    let!(:staff_award_type) { create(:award, title: "Лучший ведущий", staff: true) }
    let!(:player_award2) { create(:player_award, player: player2, award: player_award_type, season: 5, position: 2) }
    let!(:player_award1) { create(:player_award, player: player1, award: player_award_type, season: 4, position: 1) }
    let!(:staff_award2) { create(:player_award, player: organizer2, award: staff_award_type, season: 5, position: 2) }
    let!(:staff_award1) { create(:player_award, player: organizer1, award: staff_award_type, season: 4, position: 1) }
    let(:result) { described_class.call }

    it "returns a Result" do
      expect(result).to be_a(described_class::Result)
    end

    it "returns player awards ordered by position" do
      expect(result.player_awards).to eq([ player_award1, player_award2 ])
    end

    it "returns staff awards ordered by position" do
      expect(result.staff_awards).to eq([ staff_award1, staff_award2 ])
    end

    it "does not include staff awards in player awards" do
      expect(result.player_awards).not_to include(staff_award1)
    end

    it "does not include player awards in staff awards" do
      expect(result.staff_awards).not_to include(player_award1)
    end

    it "eager loads player association on player awards" do
      expect(result.player_awards.first.association(:player)).to be_loaded
    end

    it "eager loads award association on player awards" do
      expect(result.player_awards.first.association(:award)).to be_loaded
    end

    it "eager loads player association on staff awards" do
      expect(result.staff_awards.first.association(:player)).to be_loaded
    end

    it "eager loads award association on staff awards" do
      expect(result.staff_awards.first.association(:award)).to be_loaded
    end

    it "returns a loaded relation for player_awards" do
      expect(result.player_awards).to be_loaded
    end

    it "returns a loaded relation for staff_awards" do
      expect(result.staff_awards).to be_loaded
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
