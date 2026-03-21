require "rails_helper"

RSpec.describe AutosaveGameProtocolService do
  let_it_be(:competition) { create(:competition, :series) }
  let_it_be(:role_don) { create(:role, code: "don", name: "Дон") }
  let_it_be(:player) { create(:player, name: "Тестовый") }
  let_it_be(:game) { create(:game, game_number: 1, competition: competition, judge: "Судья") }

  describe ".call" do
    context "with unknown scope" do
      let(:result) { described_class.call(game: game, scope: "unknown", field: "name", value: "x") }

      it "returns failure" do
        expect(result.success).to be false
      end

      it "includes error message" do
        expect(result.errors).to include("Unknown scope: unknown")
      end
    end

    context "with game scope" do
      context "when field is allowed" do
        it "updates judge" do
          result = described_class.call(game: game, scope: "game", field: "judge", value: "Новый")

          expect(result.success).to be true
          expect(game.reload.judge).to eq("Новый")
        end

        it "updates name" do
          result = described_class.call(game: game, scope: "game", field: "name", value: "Финал")

          expect(result.success).to be true
          expect(game.reload.name).to eq("Финал")
        end

        it "updates result" do
          result = described_class.call(game: game, scope: "game", field: "result", value: "peace_victory")

          expect(result.success).to be true
          expect(game.reload).to be_peace_victory
        end

        it "updates played_on" do
          result = described_class.call(game: game, scope: "game", field: "played_on", value: "2026-03-15")

          expect(result.success).to be true
          expect(game.reload.played_on).to eq(Date.new(2026, 3, 15))
        end

        it "updates competition_id" do
          other = create(:competition, :series)
          result = described_class.call(game: game, scope: "game", field: "competition_id", value: other.id)

          expect(result.success).to be true
          expect(game.reload.competition_id).to eq(other.id)
        end

        it "updates game_number" do
          result = described_class.call(game: game, scope: "game", field: "game_number", value: "42")

          expect(result.success).to be true
          expect(game.reload.game_number).to eq(42)
        end
      end

      context "when field is disallowed" do
        let(:result) { described_class.call(game: game, scope: "game", field: "id", value: "999") }

        it "returns failure" do
          expect(result.success).to be false
        end

        it "includes field error" do
          expect(result.errors).to include("Field not allowed: id")
        end
      end

      context "when value is invalid" do
        let(:result) { described_class.call(game: game, scope: "game", field: "result", value: "bad") }

        it "returns failure" do
          expect(result.success).to be false
        end

        it "includes validation errors" do
          expect(result.errors).to be_present
        end
      end
    end

    context "with participation scope" do
      context "when field is player_name" do
        it "creates participation with existing player" do
          result = described_class.call(
            game: game, scope: "participation", field: "player_name", value: "Тестовый", seat: 1
          )

          expect(result.success).to be true
          expect(game.game_participations.find_by(seat: 1).player).to eq(player)
        end

        it "creates participation with new player" do
          expect {
            described_class.call(
              game: game, scope: "participation", field: "player_name", value: "Новичок", seat: 2
            )
          }.to change(Player, :count).by(1)
        end

        it "removes participation when value is blank" do
          create(:game_participation, game: game, player: player, seat: 3)

          expect {
            described_class.call(
              game: game, scope: "participation", field: "player_name", value: "", seat: 3
            )
          }.to change(GameParticipation, :count).by(-1)
        end

        it "succeeds when removing nonexistent participation" do
          result = described_class.call(
            game: game, scope: "participation", field: "player_name", value: "", seat: 10
          )

          expect(result.success).to be true
        end
      end

      context "when field is a regular attribute" do
        let!(:participation) { create(:game_participation, game: game, player: player, seat: 4) }

        it "updates role_code" do
          result = described_class.call(
            game: game, scope: "participation", field: "role_code", value: "don", seat: 4
          )

          expect(result.success).to be true
          expect(participation.reload.role_code).to eq("don")
        end

        it "updates plus" do
          result = described_class.call(
            game: game, scope: "participation", field: "plus", value: "1.5", seat: 4
          )

          expect(result.success).to be true
          expect(participation.reload.plus).to eq(1.5)
        end

        it "updates minus" do
          result = described_class.call(
            game: game, scope: "participation", field: "minus", value: "0.5", seat: 4
          )

          expect(result.success).to be true
          expect(participation.reload.minus).to eq(0.5)
        end

        it "updates best_move" do
          result = described_class.call(
            game: game, scope: "participation", field: "best_move", value: "0.4", seat: 4
          )

          expect(result.success).to be true
          expect(participation.reload.best_move).to eq(0.4)
        end

        it "updates win" do
          result = described_class.call(
            game: game, scope: "participation", field: "win", value: "1", seat: 4
          )

          expect(result.success).to be true
          expect(participation.reload.win).to be true
        end

        it "updates first_shoot" do
          result = described_class.call(
            game: game, scope: "participation", field: "first_shoot", value: "1", seat: 4
          )

          expect(result.success).to be true
          expect(participation.reload.first_shoot).to be true
        end

        it "updates notes" do
          result = described_class.call(
            game: game, scope: "participation", field: "notes", value: "Комментарий", seat: 4
          )

          expect(result.success).to be true
          expect(participation.reload.notes).to eq("Комментарий")
        end
      end

      context "when field is disallowed" do
        let!(:participation) { create(:game_participation, game: game, player: player, seat: 5) }

        let(:result) do
          described_class.call(
            game: game, scope: "participation", field: "game_id", value: "999", seat: 5
          )
        end

        it "returns failure" do
          expect(result.success).to be false
        end

        it "includes field error" do
          expect(result.errors).to include("Field not allowed: game_id")
        end
      end

      context "when seat is nil" do
        let(:result) do
          described_class.call(
            game: game, scope: "participation", field: "role_code", value: "don", seat: nil
          )
        end

        it "returns failure" do
          expect(result.success).to be false
        end

        it "includes error message" do
          expect(result.errors).to include("Invalid seat")
        end
      end

      context "when seat is out of range" do
        let(:result) do
          described_class.call(
            game: game, scope: "participation", field: "role_code", value: "don", seat: 11
          )
        end

        it "returns failure" do
          expect(result.success).to be false
        end

        it "includes error message" do
          expect(result.errors).to include("Invalid seat")
        end
      end

      context "when no participation exists at seat" do
        let(:result) do
          described_class.call(
            game: game, scope: "participation", field: "role_code", value: "don", seat: 9
          )
        end

        it "returns failure" do
          expect(result.success).to be false
        end

        it "includes error message" do
          expect(result.errors).to include("No participation at seat 9")
        end
      end
    end
  end
end
