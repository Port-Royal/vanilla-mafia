require "rails_helper"

RSpec.describe PlayersController do
  describe "GET /players/:id" do
    context "when player exists" do
      let_it_be(:player) { create(:player, name: "Алексей") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 1) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let_it_be(:award) { create(:award, title: "Лучший игрок") }
      let_it_be(:player_award) { create(:player_award, player: player, award: award, season: 5) }

      before { get player_path(player) }

      it "returns success" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the player name" do
        expect(response.body).to include("Алексей")
      end

      it "renders season heading" do
        expect(response.body).to include("#{I18n.t('common.season')} 5")
      end

      it "renders game link" do
        expect(response.body).to include(game_path(game))
      end

      it "renders award title" do
        expect(response.body).to include("Лучший игрок")
      end
    end

    context "when user owns the player" do
      let_it_be(:player) { create(:player, name: "Владелец") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 2) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let(:user) { create(:user, player: player) }

      before do
        sign_in user
        get player_path(player)
      end

      it "renders the edit profile link" do
        expect(response.body).to include(I18n.t("players.show.edit_profile"))
      end

      it "links to edit profile path" do
        expect(response.body).to include(edit_profile_path)
      end

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end
    end

    context "when player is unclaimed and user can claim" do
      let_it_be(:player) { create(:player, name: "Свободный") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 3) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let(:user) { create(:user) }

      before do
        sign_in user
        get player_path(player)
      end

      it "renders the claim button" do
        expect(response.body).to include(I18n.t("players.show.claim_player"))
      end

      it "renders the confirmation prompt" do
        expect(response.body).to include(I18n.t("players.show.claim_confirm"))
      end

      it "does not render the edit profile link" do
        expect(response.body).not_to include(edit_profile_path)
      end
    end

    context "when user has a pending claim for this player" do
      let_it_be(:player) { create(:player, name: "Ожидание") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 4) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let(:user) { create(:user) }

      before do
        create(:player_claim, user: user, player: player, status: "pending")
        sign_in user
        get player_path(player)
      end

      it "renders the pending claim message" do
        expect(response.body).to include(I18n.t("players.show.claim_pending"))
      end

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end

      it "does not render the edit profile link" do
        expect(response.body).not_to include(edit_profile_path)
      end
    end

    context "when user already owns a different player" do
      let_it_be(:player) { create(:player, name: "Недоступный") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 7) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let_it_be(:owned_player) { create(:player, name: "Мой игрок") }
      let(:user) { create(:user, player: owned_player) }

      before do
        sign_in user
        get player_path(player)
      end

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end

      it "does not render the edit profile link" do
        expect(response.body).not_to include(edit_profile_path)
      end
    end

    context "when user has a pending claim for a different player" do
      let_it_be(:player) { create(:player, name: "Недоступный по заявке") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 8) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let_it_be(:other_player) { create(:player, name: "Другой игрок") }
      let(:user) { create(:user) }

      before do
        create(:player_claim, user: user, player: other_player, status: "pending")
        sign_in user
        get player_path(player)
      end

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end

      it "does not render the edit profile link" do
        expect(response.body).not_to include(edit_profile_path)
      end
    end

    context "when user has a rejected claim for this player" do
      let_it_be(:player) { create(:player, name: "Отклонённый") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 9) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let(:user) { create(:user) }

      before do
        create(:player_claim, user: user, player: player, status: "rejected")
        sign_in user
        get player_path(player)
      end

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end

      it "does not render the pending claim message" do
        expect(response.body).not_to include(I18n.t("players.show.claim_pending"))
      end
    end

    context "when player is claimed by another user" do
      let_it_be(:player) { create(:player, name: "Чужой") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 5) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let_it_be(:other_user) { create(:user, player: player) }
      let(:user) { create(:user) }

      before do
        sign_in user
        get player_path(player)
      end

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end

      it "does not render the edit profile link" do
        expect(response.body).not_to include(edit_profile_path)
      end

      it "does not render the pending claim message" do
        expect(response.body).not_to include(I18n.t("players.show.claim_pending"))
      end
    end

    context "when player is claimed by another user and user can dispute" do
      let_it_be(:player) { create(:player, name: "Оспариваемый") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 10) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let_it_be(:other_user) { create(:user, player: player) }
      let(:user) { create(:user) }

      before do
        sign_in user
        get player_path(player)
      end

      it "renders the dispute button" do
        expect(response.body).to include(I18n.t("players.show.dispute_player"))
      end

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end
    end

    context "when user has a pending dispute for this player" do
      let_it_be(:player) { create(:player, name: "Спорный") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 11) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }
      let_it_be(:other_user) { create(:user, player: player) }
      let(:user) { create(:user) }

      before do
        create(:player_claim, :dispute, user: user, player: player, status: "pending")
        sign_in user
        get player_path(player)
      end

      it "renders the dispute pending message" do
        expect(response.body).to include(I18n.t("players.show.dispute_pending"))
      end

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end

      it "does not render the dispute button" do
        expect(response.body).not_to include(I18n.t("players.show.dispute_player"))
      end
    end

    context "when user is not signed in" do
      let_it_be(:player) { create(:player, name: "Аноним") }
      let_it_be(:game) { create(:game, season: 5, series: 1, game_number: 6) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }

      before { get player_path(player) }

      it "does not render the claim button" do
        expect(response.body).not_to include(I18n.t("players.show.claim_player"))
      end

      it "does not render the edit profile link" do
        expect(response.body).not_to include(edit_profile_path)
      end
    end

    context "when player does not exist" do
      before { get player_path(id: -1) }

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when player has more games than one page" do
      let_it_be(:player) { create(:player, name: "Многоигровой") }
      let_it_be(:games) do
        (1..26).map do |n|
          game = create(:game, season: 1, series: 1, game_number: n)
          create(:game_participation, game: game, player: player)
          game
        end
      end

      context "when requesting the first page" do
        before { get player_path(player) }

        it "returns success" do
          expect(response).to have_http_status(:ok)
        end

        it "renders the first 25 games" do
          (1..25).each do |n|
            expect(response.body).to include(game_path(games[n - 1]))
          end
        end

        it "does not render the 26th game" do
          expect(response.body).not_to include(game_path(games[25]))
        end

        it "renders pagination nav" do
          expect(response.body).to include("<nav")
        end
      end

      context "when requesting the second page" do
        before { get player_path(player, page: 2) }

        it "returns success" do
          expect(response).to have_http_status(:ok)
        end

        it "renders the 26th game" do
          expect(response.body).to include(game_path(games[25]))
        end

        it "does not render the first game" do
          expect(response.body).not_to include(game_path(games[0]))
        end

        it "renders pagination nav" do
          expect(response.body).to include("<nav")
        end
      end
    end

    context "when player has fewer games than one page" do
      let_it_be(:player) { create(:player, name: "Малоигровой") }
      let_it_be(:game) { create(:game, season: 1, series: 2, game_number: 1) }
      let_it_be(:participation) { create(:game_participation, game: game, player: player) }

      before { get player_path(player) }

      it "does not render pagination nav" do
        expect(response.body).not_to include("page=2")
      end
    end
  end
end
