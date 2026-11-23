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
  let_it_be(:game_breakdown) { create(:game_breakdown, author: admin) }
  let_it_be(:document) { create(:document, body: "<p>Text</p>") }

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
    "playlist_episodes" => :playlist_episode,
    "game_breakdowns" => :game_breakdown,
    "documents" => :document
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

  describe "documents editing" do
    describe "GET /avo/resources/documents/:id/edit" do
      define_method(:make_request) { get "/avo/resources/documents/#{document.slug}/edit" }

      include_examples "admin-only endpoint"
    end

    describe "GET /avo/resources/documents/new" do
      define_method(:make_request) { get "/avo/resources/documents/new" }

      include_examples "admin-only endpoint"
    end

    describe "the new document form" do
      let(:form) { Nokogiri::HTML(response.body) }

      before do
        sign_in admin
        get "/avo/resources/documents/new"
      end

      it { expect(form.at_css("[data-field-id='title'] .text-danger-content").text.strip).to eq("*") }
      it { expect(form.at_css("[data-field-id='slug']").text).to include(I18n.t("avo.document.slug_hint")) }
      it { expect(form.at_css("input[type='number'][name='document[position]']")).to be_present }
      it { expect(form.at_css("input[type='checkbox'][name='document[published]']")).to be_present }
      it { expect(form.at_css("trix-editor[input='trix_document_body']")).to be_present }
    end

    describe "POST /avo/resources/documents" do
      let(:created) { Document.find_by(title: "Правила игры") }

      before do
        sign_in admin
        post "/avo/resources/documents",
             params: { document: { title: "Правила игры", slug: "", position: "3", published: "1", body: "<p>Text</p>" } }
      end

      it { expect(created.slug).to eq("pravila-igry") }
      it { expect(created.body.to_plain_text).to eq("Text") }
      it { expect(created).to have_attributes(position: 3, published: true) }
    end
  end

  describe "player_claims (dispute)" do
    describe "GET /avo/resources/player_claims/:id" do
      define_method(:make_request) { get "/avo/resources/player_claims/#{dispute_claim.id}" }

      include_examples "admin-only endpoint"
    end
  end
end
