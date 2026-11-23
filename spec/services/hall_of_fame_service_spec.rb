require "rails_helper"

RSpec.describe HallOfFameService do
  describe ".call" do
    let_it_be(:player1) { create(:player, name: "Алексей") }
    let_it_be(:player2) { create(:player, name: "Борис") }
    let_it_be(:organizer1) { create(:player, name: "Ведущий") }
    let_it_be(:organizer2) { create(:player, name: "Главный") }
    let_it_be(:season4) { create(:competition, :season, name: "Сезон 4", started_on: Date.new(2024, 1, 1)) }
    let_it_be(:season5) { create(:competition, :season, name: "Сезон 5", started_on: Date.new(2025, 1, 1)) }
    let_it_be(:player_award_type) { create(:award, title: "Лучший игрок", staff: false) }
    let_it_be(:player_award_type2) { create(:award, title: "Лучший стратег", staff: false) }
    let_it_be(:staff_award_type) { create(:award, title: "Лучший ведущий", staff: true) }
    let_it_be(:staff_award_type2) { create(:award, title: "Лучший организатор", staff: true) }
    let_it_be(:player_award2) { create(:player_award, player: player1, award: player_award_type2, competition: season5, position: 2) }
    let_it_be(:player_award1) { create(:player_award, player: player1, award: player_award_type, competition: season4, position: 1) }
    let_it_be(:player_award3) { create(:player_award, player: player2, award: player_award_type, competition: season4, position: 3) }
    let_it_be(:staff_award2) { create(:player_award, player: organizer1, award: staff_award_type2, competition: season5, position: 2) }
    let_it_be(:staff_award1) { create(:player_award, player: organizer1, award: staff_award_type, competition: season4, position: 1) }
    let_it_be(:staff_award3) { create(:player_award, player: organizer2, award: staff_award_type, competition: season4, position: 3) }
    let(:result) { described_class.call }

    it "returns a Result" do
      expect(result).to be_a(described_class::Result)
    end

    it "returns player awards grouped by player" do
      expect(result.player_awards.keys).to contain_exactly(player1, player2)
      expect(result.player_awards.fetch(player1)).to eq([ player_award2, player_award1 ])
      expect(result.player_awards.fetch(player2)).to eq([ player_award3 ])
    end

    it "returns staff awards grouped by player" do
      expect(result.staff_awards.keys).to contain_exactly(organizer1, organizer2)
      expect(result.staff_awards.fetch(organizer1)).to eq([ staff_award2, staff_award1 ])
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

    it "returns player awards ordered by competition started_on descending" do
      expect(result.player_awards.fetch(player1)).to eq([ player_award2, player_award1 ])
    end

    it "returns staff awards ordered by competition started_on descending" do
      expect(result.staff_awards.fetch(organizer1)).to eq([ staff_award2, staff_award1 ])
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
  describe "entries for the hall of fame page" do
    let_it_be(:old_season) { create(:competition, :season, name: "Сезон 1", started_on: Date.new(2021, 1, 1)) }
    let_it_be(:new_season) { create(:competition, :season, name: "Сезон 2", started_on: Date.new(2022, 1, 1)) }
    # Created before first_award, so id order and position order disagree; 10 sorts before 2 as text.
    let_it_be(:second_award) { create(:award, title: "Глаз-алмаз", position: 10) }
    let_it_be(:first_award) do
      create(:award, title: "Победитель", position: 2).tap do |award|
        award.icon.attach(io: StringIO.new("icon"), filename: "icon.png", content_type: "image/png")
      end
    end
    let_it_be(:unplaced_award) { create(:award, title: "Без места") }
    let_it_be(:later_unplaced_award) { create(:award, title: "Тоже без места") }
    let_it_be(:staff_award) { create(:award, title: "Организатор", staff: true) }
    let_it_be(:champion) do
      create(:player, name: "Чемпион").tap do |player|
        player.photo.attach(io: Rails.root.join("spec/fixtures/files/selfie.jpg").open, filename: "selfie.jpg",
                            content_type: "image/jpeg")
      end
    end
    let_it_be(:recent) { create(:player, name: "Свежий") }
    let_it_be(:earlier) { create(:player, name: "Давний") }
    let_it_be(:same_season) { create(:player, name: "Ровесник") }
    let_it_be(:organizer) { create(:player, name: "Ведущий") }

    before_all do
      create(:player_award, player: earlier, award: first_award, competition: old_season)
      create(:player_award, player: earlier, award: second_award, competition: old_season)
      create(:player_award, player: champion, award: later_unplaced_award, competition: new_season)
      create(:player_award, player: champion, award: second_award, competition: new_season)
      create(:player_award, player: champion, award: unplaced_award, competition: old_season)
      create(:player_award, player: champion, award: second_award, competition: old_season)
      create(:player_award, player: champion, award: first_award)
      create(:player_award, player: same_season, award: second_award, competition: new_season)
      create(:player_award, player: recent, award: first_award, competition: new_season)
      create(:player_award, player: organizer, award: staff_award)
    end

    let(:result) { described_class.call }
    let(:entries) { result.player_entries }
    let(:champion_entry) { entries.first }

    it "puts players with the most award records first, ties by their latest award, then by entry order" do
      expect(entries.map(&:player)).to eq([ champion, earlier, same_season, recent ])
    end

    it "counts every award record of a player" do
      expect(champion_entry.awards_count).to eq(5)
    end

    it "merges repeat wins into one badge per award, by award position, unplaced awards last by id" do
      expect(champion_entry.badges.map(&:award)).to eq([ first_award, second_award, unplaced_award, later_unplaced_award ])
    end

    it "lists the competitions of a badge newest first" do
      expect(champion_entry.badges.second.competitions).to eq([ new_season, old_season ])
    end

    it "lists no competitions for an award won without one" do
      expect(champion_entry.badges.first.competitions).to eq([])
    end

    it "builds badges for the other players too" do
      expect(entries.second.badges.map(&:award)).to eq([ first_award, second_award ])
    end

    it "eager loads player photo blobs" do
      expect(champion_entry.player.photo_attachment.association(:blob)).to be_loaded
    end

    it "eager loads award icon blobs" do
      expect(champion_entry.badges.first.award.icon_attachment.association(:blob)).to be_loaded
    end

    it "returns staff entries separately" do
      expect(result.staff_entries.map(&:player)).to eq([ organizer ])
    end

    it "builds staff badges" do
      expect(result.staff_entries.first.badges.map(&:award)).to eq([ staff_award ])
    end
  end
end
