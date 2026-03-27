require "rails_helper"

RSpec.describe HomeController do
  describe "GET /" do
    before { get root_path }

    it "returns success" do
      expect(response).to have_http_status(:ok)
    end

    it "does not redirect" do
      expect(response).not_to have_http_status(:redirect)
    end

    it "renders within the application layout" do
      expect(response.body).to include("Vanilla Mafia")
    end
  end

  describe "running tournaments block" do
    context "when running competitions with players exist" do
      let_it_be(:competition) { create(:competition, :season, name: "Season 6", ended_on: nil) }
      let_it_be(:child) { create(:competition, :series, parent: competition, name: "Series 1") }
      let_it_be(:role) { create(:role) }
      let_it_be(:players) do
        (1..6).map { |i| create(:player, name: "Player #{i}") }
      end
      let_it_be(:game) { create(:game, competition: child) }

      before_all do
        players.each_with_index do |player, i|
          create(:game_participation, game: game, player: player, role: role, plus: 10 - i)
        end
      end

      before { get root_path }

      it "renders the section title" do
        expect(response.body).to include(I18n.t("home.running_tournaments.running_tournaments"))
      end

      it "renders the competition name" do
        expect(response.body).to include("Season 6")
      end

      it "renders a link to the competition page" do
        expect(response.body).to include(competition_path(slug: competition.slug))
      end

      it "renders top 5 players" do
        (1..5).each do |i|
          expect(response.body).to include("Player #{i}")
        end
      end

      it "does not render the 6th player" do
        expect(response.body).not_to include("Player 6")
      end

      it "renders player ratings" do
        expect(response.body).to include("10.0")
      end

      it "ranks players by rating descending" do
        body = response.body
        pos_player1 = body.index("Player 1")
        pos_player5 = body.index("Player 5")
        expect(pos_player1).to be < pos_player5
      end
    end

    context "when only child competitions are running" do
      let_it_be(:parent) { create(:competition, :season, name: "Parent Season", ended_on: nil) }
      let_it_be(:child_running) { create(:competition, :series, parent: parent, name: "Child Series", ended_on: nil) }

      before { get root_path }

      it "shows root competitions only" do
        expect(response.body).to include("Parent Season")
        expect(response.body).not_to include("Child Series")
      end
    end

    context "when multiple running competitions exist" do
      let_it_be(:second) { create(:competition, :season, name: "Second Comp", ended_on: nil, position: 2) }
      let_it_be(:first) { create(:competition, :season, name: "First Comp", ended_on: nil, position: 1) }

      before { get root_path }

      it "orders competitions by position" do
        body = response.body
        pos_first = body.index("First Comp")
        pos_second = body.index("Second Comp")
        expect(pos_first).to be < pos_second
      end
    end

    context "when no running competitions exist" do
      let_it_be(:finished) { create(:competition, :season, name: "Season 5", ended_on: Date.new(2025, 12, 31)) }

      before { get root_path }

      it "does not render the running tournaments section" do
        expect(response.body).not_to include(I18n.t("home.running_tournaments.running_tournaments"))
      end
    end

    context "when a running competition has no games yet" do
      let_it_be(:empty_competition) { create(:competition, :season, name: "Empty Season", ended_on: nil) }

      before { get root_path }

      it "renders the competition name" do
        expect(response.body).to include("Empty Season")
      end

      it "does not render a standings table for it" do
        expect(response.body).not_to include("<table")
      end
    end
  end
end
