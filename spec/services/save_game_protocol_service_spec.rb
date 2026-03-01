require "rails_helper"

RSpec.describe SaveGameProtocolService do
  describe ".call" do
    let_it_be(:role_don) { create(:role, code: "don", name: "Дон") }
    let_it_be(:role_maf) { create(:role, code: "maf", name: "Мафия") }
    let_it_be(:existing_player) { create(:player, name: "Алексей") }

    let(:game) { Game.new }
    let(:game_params) do
      { season: 5, series: 1, game_number: 1, played_on: "2026-01-15", name: "Тестовая", result: "Победа мирных", judge: "Иван" }
    end

    context "when creating a new game with participations" do
      let(:participations_params) do
        params = {}
        params["1"] = { player_name: "Алексей", role_code: "don", plus: "1", minus: "0", best_move: "0.5", win: "0", first_shoot: "0", notes: "Капитан" }
        params["2"] = { player_name: "Новый Игрок", role_code: "maf", plus: "0", minus: "1", best_move: "", win: "0", first_shoot: "1", notes: "" }
        (3..10).each { |i| params[i.to_s] = { player_name: "", role_code: "", plus: "", minus: "", best_move: "", win: "0", first_shoot: "0", notes: "" } }
        ActionController::Parameters.new(params).permit!
      end

      it "returns a successful result" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.success).to be true
      end

      it "creates the game" do
        expect {
          described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        }.to change(Game, :count).by(1)
      end

      it "sets game attributes correctly" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.game).to have_attributes(season: 5, series: 1, game_number: 1, judge: "Иван")
      end

      it "creates participations for filled seats" do
        expect {
          described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        }.to change(GameParticipation, :count).by(2)
      end

      it "assigns the existing player by name" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        participation = result.game.game_participations.find_by(seat: 1)
        expect(participation.player).to eq(existing_player)
      end

      it "creates a new player when not found" do
        expect {
          described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        }.to change(Player, :count).by(1)
      end

      it "sets role_code on participation" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        participation = result.game.game_participations.find_by(seat: 1)
        expect(participation.role_code).to eq("don")
      end

      it "sets numeric fields on participation" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        participation = result.game.game_participations.find_by(seat: 1)
        expect(participation).to have_attributes(plus: 1, minus: 0, best_move: 0.5)
      end

      it "sets notes on participation" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        participation = result.game.game_participations.find_by(seat: 1)
        expect(participation.notes).to eq("Капитан")
      end

      it "sets first_shoot correctly" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        participation = result.game.game_participations.find_by(seat: 2)
        expect(participation.first_shoot).to be true
      end

      it "skips seats with blank player_name" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.game.game_participations.count).to eq(2)
      end
    end

    context "when game params are invalid" do
      let(:invalid_game_params) { { season: nil, series: 1, game_number: 1 } }
      let(:participations_params) do
        params = {}
        (1..10).each { |i| params[i.to_s] = { player_name: "", role_code: "" } }
        ActionController::Parameters.new(params).permit!
      end

      it "returns a failure result" do
        result = described_class.call(game: game, game_params: invalid_game_params, participations_params: participations_params)
        expect(result.success).to be false
      end

      it "does not create a game" do
        expect {
          described_class.call(game: game, game_params: invalid_game_params, participations_params: participations_params)
        }.not_to change(Game, :count)
      end

      it "includes error messages" do
        result = described_class.call(game: game, game_params: invalid_game_params, participations_params: participations_params)
        expect(result.errors).not_to be_empty
      end
    end

    context "when updating an existing game" do
      let!(:game_to_update) { create(:game, season: 5, series: 1, game_number: 2, judge: "Старый") }
      let!(:old_participation) { create(:game_participation, game: game_to_update, player: existing_player, seat: 1) }
      let(:update_game_params) { { season: 5, series: 1, game_number: 2, judge: "Новый" } }
      let(:participations_params) do
        params = {}
        params["1"] = { player_name: "Алексей", role_code: "don", plus: "2", minus: "0", best_move: "", win: "1", first_shoot: "0", notes: "" }
        (2..10).each { |i| params[i.to_s] = { player_name: "", role_code: "" } }
        ActionController::Parameters.new(params).permit!
      end

      it "updates game attributes" do
        result = described_class.call(game: game_to_update, game_params: update_game_params, participations_params: participations_params)
        expect(result.game.reload.judge).to eq("Новый")
      end

      it "updates existing participation" do
        described_class.call(game: game_to_update, game_params: update_game_params, participations_params: participations_params)
        expect(old_participation.reload.plus).to eq(2)
      end

      it "sets win on updated participation" do
        described_class.call(game: game_to_update, game_params: update_game_params, participations_params: participations_params)
        expect(old_participation.reload.win).to be true
      end
    end

    context "when clearing a previously filled seat" do
      let!(:game_to_update) { create(:game, season: 5, series: 1, game_number: 3) }
      let!(:participation_to_remove) { create(:game_participation, game: game_to_update, player: existing_player, seat: 1) }
      let(:participations_params) do
        params = {}
        (1..10).each { |i| params[i.to_s] = { player_name: "", role_code: "" } }
        ActionController::Parameters.new(params).permit!
      end

      it "removes the participation" do
        expect {
          described_class.call(game: game_to_update, game_params: { season: 5, series: 1, game_number: 3 }, participations_params: participations_params)
        }.to change(GameParticipation, :count).by(-1)
      end
    end
  end
end
