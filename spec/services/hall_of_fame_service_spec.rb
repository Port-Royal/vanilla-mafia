require "rails_helper"

RSpec.describe HallOfFameService do
  describe ".call" do
    let_it_be(:player1) { create(:player, name: "Алексей") }
    let_it_be(:player2) { create(:player, name: "Борис") }
    let_it_be(:organizer1) { create(:player, name: "Ведущий") }
    let_it_be(:organizer2) { create(:player, name: "Главный") }
    let_it_be(:season4) { create(:competition, :season, name: "Сезон 4") }
    let_it_be(:season5) { create(:competition, :season, name: "Сезон 5") }
    let_it_be(:player_award_type) { create(:award, title: "Лучший игрок", staff: false) }
    let_it_be(:player_award_type2) { create(:award, title: "Лучший стратег", staff: false) }
    let_it_be(:staff_award_type) { create(:award, title: "Лучший ведущий", staff: true) }
    let_it_be(:staff_award_type2) { create(:award, title: "Лучший организатор", staff: true) }
    let_it_be(:player_award2) { create(:player_award, player: player1, award: player_award_type2, competition: season5, season: 5, position: 2) }
    let_it_be(:player_award1) { create(:player_award, player: player1, award: player_award_type, competition: season4, season: 4, position: 1) }
    let_it_be(:player_award3) { create(:player_award, player: player2, award: player_award_type, competition: season4, season: 4, position: 3) }
    let_it_be(:staff_award2) { create(:player_award, player: organizer1, award: staff_award_type2, competition: season5, season: 5, position: 2) }
    let_it_be(:staff_award1) { create(:player_award, player: organizer1, award: staff_award_type, competition: season4, season: 4, position: 1) }
    let_it_be(:staff_award3) { create(:player_award, player: organizer2, award: staff_award_type, competition: season4, season: 4, position: 3) }
    let(:result) { described_class.call }

    it "returns a Result" do
      expect(result).to be_a(described_class::Result)
    end

    it "returns player awards grouped by player" do
      expect(result.player_awards.keys).to contain_exactly(player1, player2)
      expect(result.player_awards.fetch(player1)).to eq([ player_award1, player_award2 ])
      expect(result.player_awards.fetch(player2)).to eq([ player_award3 ])
    end

    it "returns staff awards grouped by player" do
      expect(result.staff_awards.keys).to contain_exactly(organizer1, organizer2)
      expect(result.staff_awards.fetch(organizer1)).to eq([ staff_award1, staff_award2 ])
      expect(result.staff_awards.fetch(organizer2)).to eq([ staff_award3 ])
    end

    it "does not include staff awards in player awards" do
      expect(result.player_awards.keys).not_to include(organizer1, organizer2)
    end

    it "does not include player awards in staff awards" do
      expect(result.staff_awards.keys).not_to include(player1, player2)
    end

    it "eager loads player association on player awards" do
      expect(result.player_awards.fetch(player1).first.association(:player)).to be_loaded
    end

    it "eager loads award association on player awards" do
      expect(result.player_awards.fetch(player1).first.association(:award)).to be_loaded
    end

    it "eager loads player association on staff awards" do
      expect(result.staff_awards.fetch(organizer1).first.association(:player)).to be_loaded
    end

    it "eager loads award association on staff awards" do
      expect(result.staff_awards.fetch(organizer1).first.association(:award)).to be_loaded
    end

    it "eager loads competition association on player awards" do
      expect(result.player_awards.fetch(player1).first.association(:competition)).to be_loaded
    end

    it "eager loads competition association on staff awards" do
      expect(result.staff_awards.fetch(organizer1).first.association(:competition)).to be_loaded
    end

    it "eager loads photo attachment on players" do
      player_award = result.player_awards.fetch(player1).first
      expect(player_award.player.association(:photo_attachment)).to be_loaded
    end

    it "eager loads icon attachment on awards" do
      player_award = result.player_awards.fetch(player1).first
      expect(player_award.award.association(:icon_attachment)).to be_loaded
    end

    it "returns player awards ordered by position within a player" do
      expect(result.player_awards.fetch(player1)).to eq([ player_award1, player_award2 ])
    end

    it "returns staff awards ordered by position within a player" do
      expect(result.staff_awards.fetch(organizer1)).to eq([ staff_award1, staff_award2 ])
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
