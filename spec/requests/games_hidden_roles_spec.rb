require "rails_helper"

RSpec.describe "Roles of a game with hidden roles" do
  let_it_be(:role_don) { create(:role, code: "don", name: "Дон") }
  let_it_be(:role_sheriff) { create(:role, code: "sheriff", name: "Шериф") }

  let(:game) { create(:game, hide_roles:, result:) }
  let!(:don) { create(:game_participation, game:, seat: 1, role_code: "don", best_move_seats: [ 2 ]) }
  let!(:sheriff) { create(:game_participation, game:, seat: 2, role_code: "sheriff") }
  let(:canvas) { css_select("#game-overlay").first }
  let(:badge_texts) { css_select(".overlay-role-badge").map { |badge| badge.text.strip }.reject(&:empty?) }
  let(:best_move_colours) { css_select(".overlay-best-move-cell").map { |cell| cell["data-colour"] } }

  shared_examples "roles are not served" do
    context "with the overlay" do
      before { get overlay_game_path(game) }

      it "sends no seat roles" do
        expect(JSON.parse(canvas["data-game-overlay-seat-roles-value"])).to eq({})
      end

      it "renders no badges" do
        expect(badge_texts).to be_empty
      end

      it "paints best move cells neutral" do
        expect(best_move_colours).to eq([ "neutral" ])
      end

      it "marks the canvas as hiding roles" do
        expect(canvas["class"]).to include("overlay-canvas--hide-roles")
      end
    end

    context "with the game page" do
      before { get game_path(game) }

      it "renders no role icons" do
        assert_select "img[src*='roles/']", count: 0
      end
    end

    context "with the player page" do
      before { get player_path(don.player) }

      it "does not name the role" do
        expect(response.body).not_to include("Дон")
      end
    end
  end

  shared_examples "roles are served" do
    context "with the overlay" do
      before { get overlay_game_path(game) }

      it "sends seat roles" do
        expect(JSON.parse(canvas["data-game-overlay-seat-roles-value"])).to eq("1" => "don", "2" => "sheriff")
      end

      it "renders badges" do
        expect(badge_texts.size).to eq(2)
      end

      it "colours best move cells" do
        expect(best_move_colours).to eq([ "red" ])
      end

      it "does not mark the canvas as hiding roles" do
        expect(canvas["class"]).not_to include("overlay-canvas--hide-roles")
      end
    end

    context "with the game page" do
      before { get game_path(game) }

      it "renders role icons" do
        assert_select "img[src*='roles/']", count: 2
      end
    end

    context "with the player page" do
      before { get player_path(don.player) }

      it "names the role" do
        expect(response.body).to include("Дон")
      end
    end
  end

  context "when a player has a game without a role" do
    let(:hide_roles) { false }
    let(:result) { "draw" }
    let!(:roleless) { create(:game_participation, game:, seat: 3, role_code: nil) }

    before { get player_path(roleless.player) }

    it "renders the player page" do
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the game runs with hide_roles on" do
    let(:hide_roles) { true }
    let(:result) { "in_progress" }

    it_behaves_like "roles are not served"
  end

  context "when the game runs with hide_roles off" do
    let(:hide_roles) { false }
    let(:result) { "in_progress" }

    it_behaves_like "roles are served"
  end

  context "when the game finished with hide_roles on" do
    let(:hide_roles) { true }
    let(:result) { "draw" }

    it_behaves_like "roles are served"
  end
end
