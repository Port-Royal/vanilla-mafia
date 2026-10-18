require "rails_helper"

RSpec.describe SaveGameProtocolService do
  describe ".call" do
    let_it_be(:role_don) { create(:role, code: "don", name: "Дон") }
    let_it_be(:role_maf) { create(:role, code: "maf", name: "Мафия") }
    let_it_be(:existing_player) { create(:player, name: "Алексей") }
    let_it_be(:competition) { create(:competition, :series) }

    let(:game) { Game.new }
    let(:game_params) do
      { game_number: 1, played_on: "2026-01-15", name: "Тестовая", result: "peace_victory", judge: "Иван", competition_id: competition.id }
    end

    context "when creating a new game with participations" do
      let(:participations_params) do
        params = {}
        params["1"] = { player_name: "Алексей", role_code: "don", plus: "1", minus: "0", best_move: "0.5", first_shoot: "0", notes: "Капитан" }
        params["2"] = { player_name: "Новый Игрок", role_code: "maf", plus: "0", minus: "1", best_move: "", first_shoot: "1", notes: "", best_move_seats: [ "1", "", "5" ] }
        (3..10).each { |i| params[i.to_s] = { player_name: "", role_code: "", plus: "", minus: "", best_move: "", first_shoot: "0", notes: "" } }
        ActionController::Parameters.new(params).permit!
      end

      it "returns a successful result" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.success).to be true
      end

      it "returns no errors" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.errors).to eq([])
      end

      it "creates the game" do
        expect {
          described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        }.to change(Game, :count).by(1)
      end

      it "sets game attributes correctly" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.game).to have_attributes(game_number: 1, judge: "Иван")
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

      it "leaves first_shoot off when not checked" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.game.game_participations.find_by(seat: 1).first_shoot).to be false
      end

      it "stores blank notes as nil and keeps submitted minus" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.game.game_participations.find_by(seat: 2)).to have_attributes(notes: nil, minus: 1)
      end

      it "sets best move seats" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.game.game_participations.find_by(seat: 2).best_move_seats).to eq([ 1, 5 ])
      end

      it "leaves best move seats empty when not submitted" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.game.game_participations.find_by(seat: 1).best_move_seats).to be_nil
      end

      it "skips seats with blank player_name" do
        result = described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        expect(result.game.game_participations.count).to eq(2)
      end
    end

    context "when game params are invalid" do
      let(:invalid_game_params) { { game_number: nil, competition_id: competition.id } }
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
        expect(result.errors).to match([ a_string_including("Номер игры не может быть пустым") ])
      end

      it "returns the game" do
        result = described_class.call(game: game, game_params: invalid_game_params, participations_params: participations_params)
        expect(result.game).to be(game)
      end
    end

    context "when updating an existing game" do
      let!(:game_to_update) { create(:game, game_number: 2, judge: "Старый") }
      let!(:old_participation) { create(:game_participation, game: game_to_update, player: existing_player, seat: 1) }
      let(:update_game_params) { { game_number: 2, judge: "Новый" } }
      let(:participations_params) do
        params = {}
        params["1"] = { player_name: "Алексей", role_code: "don", plus: "2", minus: "1", best_move: "0.25", first_shoot: "0", notes: "Новое" }
        (2..10).each { |i| params[i.to_s] = { player_name: "", role_code: "" } }
        ActionController::Parameters.new(params).permit!
      end

      it "updates game attributes" do
        result = described_class.call(game: game_to_update, game_params: update_game_params, participations_params: participations_params)
        expect(result.game.reload.judge).to eq("Новый")
      end

      it "updates existing participation" do
        described_class.call(game: game_to_update, game_params: update_game_params, participations_params: participations_params)
        expect(old_participation.reload).to have_attributes(role_code: "don", plus: 2, minus: 1, best_move: 0.25, notes: "Новое")
      end

      it "does not modify win (not set from protocol form)" do
        old_participation.update!(win: true)
        described_class.call(game: game_to_update, game_params: update_game_params, participations_params: participations_params)
        expect(old_participation.reload.win).to be true
      end

      it "persists status when provided" do
        params = { "1" => { player_name: "Алексей", role_code: "don", plus: "2", minus: "0", best_move: "", first_shoot: "0", notes: "", status: "voted_out" } }
        (2..10).each { |i| params[i.to_s] = { player_name: "", role_code: "" } }
        described_class.call(
          game: game_to_update,
          game_params: update_game_params,
          participations_params: ActionController::Parameters.new(params).permit!
        )
        expect(old_participation.reload.status).to eq("voted_out")
      end

      it "ignores an invalid status value without raising" do
        params = { "1" => { player_name: "Алексей", role_code: "don", plus: "2", minus: "0", best_move: "", first_shoot: "0", notes: "", status: "vaporized" } }
        (2..10).each { |i| params[i.to_s] = { player_name: "", role_code: "" } }
        expect {
          described_class.call(
            game: game_to_update,
            game_params: update_game_params,
            participations_params: ActionController::Parameters.new(params).permit!
          )
        }.not_to raise_error
        expect(old_participation.reload.status).to eq("alive")
      end
    end

    context "when clearing a previously filled seat" do
      let!(:game_to_update) { create(:game, game_number: 3) }
      let!(:participation_to_remove) { create(:game_participation, game: game_to_update, player: existing_player, seat: 1) }
      let(:participations_params) do
        params = {}
        (1..10).each { |i| params[i.to_s] = { player_name: "", role_code: "" } }
        ActionController::Parameters.new(params).permit!
      end

      it "removes the participation" do
        expect {
          described_class.call(game: game_to_update, game_params: { game_number: 3 }, participations_params: participations_params)
        }.to change(GameParticipation, :count).by(-1)
      end
    end

    context "when game has legacy participations without seats" do
      let_it_be(:other_player) { create(:player, name: "Борис") }
      let!(:game_to_update) { create(:game, game_number: 4) }
      let!(:legacy_participation) { create(:game_participation, game: game_to_update, player: existing_player, seat: nil) }
      let(:participations_params) do
        params = {}
        params["1"] = { player_name: "Алексей", role_code: "don", plus: "1", minus: "0", best_move: "", first_shoot: "0", notes: "" }
        (2..10).each { |i| params[i.to_s] = { player_name: "", role_code: "" } }
        ActionController::Parameters.new(params).permit!
      end

      it "assigns a seat to the legacy participation" do
        described_class.call(game: game_to_update, game_params: { game_number: 4 }, participations_params: participations_params)
        expect(legacy_participation.reload.seat).to eq(1)
      end

      it "does not create a duplicate participation" do
        expect {
          described_class.call(game: game_to_update, game_params: { game_number: 4 }, participations_params: participations_params)
        }.not_to change(GameParticipation, :count)
      end
    end

    context "when a participation fails validation after the game is saved" do
      let(:participations_params) do
        ActionController::Parameters.new("1" => { player_name: "Алексей", best_move_seats: [ "1" ] }).permit!
      end
      let(:result) { described_class.call(game: game, game_params: game_params, participations_params: participations_params) }

      it "rolls back the game" do
        expect { result }.not_to change(Game, :count)
      end

      it "returns a failure with the validation message" do
        expect(result).to have_attributes(
          success: false,
          game: game,
          errors: [ a_string_including("Лучший ход: места не может включать место самого игрока") ]
        )
      end
    end

    context "when submitted attributes are sparse" do
      let(:participations_params) do
        ActionController::Parameters.new(
          "1" => {},
          "2" => { player_name: "  Алексей  " },
          "3" => { player_name: "   " }
        ).permit!
      end
      let(:result) { described_class.call(game: game, game_params: game_params, participations_params: participations_params) }
      let(:seated) { result.game.game_participations.find_by(seat: 2) }

      it "seats the player after a blank seat, matching the stripped name" do
        expect(seated.player).to eq(existing_player)
      end

      it "only creates the filled seat" do
        expect(result.game.game_participations.pluck(:seat)).to eq([ 2 ])
      end

      it "leaves unsubmitted attributes empty" do
        expect(seated).to have_attributes(
          role_code: nil, plus: nil, minus: nil, best_move: nil, first_shoot: false, notes: nil, status: "alive", best_move_seats: nil
        )
      end
    end

    context "when one of several seats is cleared" do
      let_it_be(:boris) { create(:player, name: "Борис") }
      let!(:game_to_update) { create(:game) }
      let!(:kept) { create(:game_participation, game: game_to_update, player: existing_player, seat: 1) }
      let!(:cleared) { create(:game_participation, game: game_to_update, player: boris, seat: 2) }
      let(:participations_params) do
        ActionController::Parameters.new("1" => { player_name: "Алексей" }, "2" => { player_name: "" }).permit!
      end

      before do
        described_class.call(game: game_to_update, game_params: {}, participations_params: participations_params)
      end

      it "removes only the cleared seat" do
        expect(game_to_update.game_participations.reload).to contain_exactly(kept)
      end
    end

    context "when saving raises a uniqueness race" do
      let(:participations_params) { ActionController::Parameters.new("1" => { player_name: "Гонка" }).permit! }
      let(:result) { described_class.call(game: game, game_params: game_params, participations_params: participations_params) }

      before do
        allow(Player).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordNotUnique, "duplicate player")
      end

      it "returns a failure with the error message" do
        expect(result).to have_attributes(success: false, errors: [ "duplicate player" ])
      end

      it "rolls back the game" do
        expect { result }.not_to change(Game, :count)
      end
    end

    context "when saving raises an unexpected error" do
      let(:participations_params) { ActionController::Parameters.new("1" => { player_name: "Сбой" }).permit! }

      before do
        allow(Player).to receive(:find_or_create_by!).and_raise(ArgumentError, "boom")
      end

      it "lets the error propagate" do
        expect {
          described_class.call(game: game, game_params: game_params, participations_params: participations_params)
        }.to raise_error(ArgumentError, "boom")
      end
    end

    context "when a seat is cleared to whitespace" do
      let!(:game_to_update) { create(:game) }
      let!(:participation) { create(:game_participation, game: game_to_update, player: existing_player, seat: 10) }
      let(:participations_params) { ActionController::Parameters.new("10" => { player_name: "   " }).permit! }

      it "removes the participation" do
        described_class.call(game: game_to_update, game_params: {}, participations_params: participations_params)
        expect(GameParticipation.exists?(participation.id)).to be false
      end
    end

    context "when legacy participations join a partly seated game" do
      let_it_be(:boris) { create(:player, name: "Борис") }
      let_it_be(:viktor) { create(:player, name: "Виктор") }
      let!(:game_to_update) { create(:game) }
      let!(:seated) { create(:game_participation, game: game_to_update, player: boris, seat: 1) }
      let!(:first_legacy) { create(:game_participation, game: game_to_update, player: existing_player, seat: nil) }
      let!(:second_legacy) { create(:game_participation, game: game_to_update, player: viktor, seat: nil) }
      let(:participations_params) do
        ActionController::Parameters.new(
          "1" => { player_name: "Борис" }, "2" => { player_name: "Алексей" }, "3" => { player_name: "Виктор" }
        ).permit!
      end

      before do
        described_class.call(game: game_to_update, game_params: {}, participations_params: participations_params)
      end

      it "assigns free seats in creation order, skipping taken ones" do
        expect([ seated, first_legacy, second_legacy ].map { |gp| gp.reload.seat }).to eq([ 1, 2, 3 ])
      end
    end

    context "when only seat ten is free for a legacy participation" do
      let_it_be(:players) { create_list(:player, 9) }
      let!(:game_to_update) { create(:game) }
      let!(:legacy) { create(:game_participation, game: game_to_update, player: existing_player, seat: nil) }
      let(:participations_params) do
        params = players.each_with_index.to_h { |player, idx| [ (idx + 1).to_s, { player_name: player.name } ] }
        ActionController::Parameters.new(params.merge("10" => { player_name: "Алексей" })).permit!
      end

      before do
        players.each_with_index { |player, idx| create(:game_participation, game: game_to_update, player: player, seat: idx + 1) }
      end

      it "assigns seat ten" do
        described_class.call(game: game_to_update, game_params: {}, participations_params: participations_params)
        expect(legacy.reload.seat).to eq(10)
      end
    end

    context "when every seat is taken and a legacy participation has none" do
      let_it_be(:players) { create_list(:player, 10) }
      let!(:game_to_update) { create(:game) }
      let!(:legacy) { create(:game_participation, game: game_to_update, player: existing_player, seat: nil) }
      let(:result) { described_class.call(game: game_to_update, game_params: {}, participations_params: participations_params) }

      before do
        players.each_with_index { |player, idx| create(:game_participation, game: game_to_update, player: player, seat: idx + 1) }
      end

      context "when all seats stay filled" do
        let(:participations_params) do
          ActionController::Parameters.new(players.each_with_index.to_h { |player, idx| [ (idx + 1).to_s, { player_name: player.name } ] }).permit!
        end

        it "succeeds" do
          expect(result.success).to be true
        end

        it "leaves the legacy participation unseated" do
          result
          expect(legacy.reload.seat).to be_nil
        end
      end

      context "when all seats are cleared" do
        let(:participations_params) do
          ActionController::Parameters.new((1..10).to_h { |seat| [ seat.to_s, { player_name: "" } ] }).permit!
        end

        it "removes only the seated participations" do
          result
          expect(game_to_update.game_participations.reload).to contain_exactly(legacy)
        end
      end
    end
  end
end
