# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Avo admin resources" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:non_admin) { create(:user) }
  let_it_be(:player) { create(:player) }
  let_it_be(:game) { create(:game) }
  let_it_be(:role) { create(:role) }
  let_it_be(:award) { create(:award) }
  let_it_be(:game_participation) { create(:game_participation, game: game, player: player) }
  let_it_be(:player_award) { create(:player_award, player: player, award: award) }
  let_it_be(:feature_toggle) { create(:feature_toggle) }
  let_it_be(:episode) { create(:episode) }
  let_it_be(:playlist) { create(:playlist) }
  let_it_be(:playlist_episode) { create(:playlist_episode, playlist: playlist, episode: episode) }
  let_it_be(:player_claim) { create(:player_claim, user: non_admin, player: player) }
  let_it_be(:claimed_player) { create(:player, user: create(:user)) }
  let_it_be(:dispute_claim) { create(:player_claim, :dispute, user: admin, player: claimed_player) }

  shared_examples "admin-only endpoint" do
    context "when not signed in" do
      it "redirects to sign in" do
        make_request
        expect(response).to redirect_to("/users/sign_in")
      end
    end

    context "when signed in as non-admin" do
      before { sign_in non_admin }

      it "denies access" do
        make_request
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as admin" do
      before { sign_in admin }

      it "grants access" do
        make_request
        follow_redirect! while response.redirect?
        expect(response).to have_http_status(:ok)
      end
    end
  end

  {
    "players" => :player,
    "games" => :game,
    "roles" => :role,
    "awards" => :award,
    "game_participations" => :game_participation,
    "player_awards" => :player_award,
    "users" => :admin,
    "feature_toggles" => :feature_toggle,
    "player_claims" => :player_claim,
    "episodes" => :episode,
    "playlists" => :playlist,
    "playlist_episodes" => :playlist_episode
  }.each do |resource_name, record_method|
    describe resource_name do
      describe "GET /avo/resources/#{resource_name}" do
        define_method(:make_request) { get "/avo/resources/#{resource_name}" }

        include_examples "admin-only endpoint"
      end

      describe "GET /avo/resources/#{resource_name}/:id" do
        define_method(:make_request) { get "/avo/resources/#{resource_name}/#{send(record_method).id}" }

        include_examples "admin-only endpoint"
      end
    end
  end

  describe "player_claims (dispute)" do
    describe "GET /avo/resources/player_claims/:id" do
      define_method(:make_request) { get "/avo/resources/player_claims/#{dispute_claim.id}" }

      include_examples "admin-only endpoint"
    end
  end
end
