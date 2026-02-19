require "rails_helper"

RSpec.describe PlayerProfileService do
  describe ".call" do
    let_it_be(:player) { create(:player, name: "Алексей") }
    let_it_be(:game2) { create(:game, season: 5, series: 1, game_number: 2) }
    let_it_be(:game1) { create(:game, season: 5, series: 1, game_number: 1) }
    let_it_be(:game3) { create(:game, season: 6, series: 1, game_number: 1) }
    let_it_be(:rating2) { create(:rating, game: game2, player: player) }
    let_it_be(:rating1) { create(:rating, game: game1, player: player) }
    let_it_be(:rating3) { create(:rating, game: game3, player: player) }
    let_it_be(:award1) { create(:award, title: "Лучший игрок") }
    let_it_be(:award2) { create(:award, title: "Лучший стратег") }
    let_it_be(:player_award1) { create(:player_award, player: player, award: award1, season: 5, position: 2) }
    let_it_be(:player_award2) { create(:player_award, player: player, award: award2, season: 5, position: 1) }
    let(:result) { described_class.call(player_id: player.id) }

    it "returns a Result" do
      expect(result).to be_a(described_class::Result)
    end

    it "returns the player" do
      expect(result.player).to eq(player)
    end

    it "groups games by season" do
      expect(result.games_by_season.keys).to contain_exactly(5, 6)
    end

    it "orders games within each season" do
      expect(result.games_by_season[5]).to eq([ game1, game2 ])
    end

    it "returns player awards ordered by position" do
      expect(result.player_awards).to eq([ player_award2, player_award1 ])
    end

    it "eager loads award association" do
      expect(result.player_awards.first.association(:award)).to be_loaded
    end

    it "returns a loaded relation for player_awards" do
      expect(result.player_awards).to be_loaded
    end

    context "when player has no games or awards" do
      let_it_be(:lonely_player) { create(:player, name: "Одинокий") }
      let(:lonely_result) { described_class.call(player_id: lonely_player.id) }

      it "returns empty games_by_season" do
        expect(lonely_result.games_by_season).to be_empty
      end

      it "returns empty player_awards" do
        expect(lonely_result.player_awards).to be_empty
      end
    end

    context "when player does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect { described_class.call(player_id: -1) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
