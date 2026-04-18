require "rails_helper"

RSpec.describe GameProtocolChannel do
  let_it_be(:competition) { create(:competition, :series) }
  let_it_be(:in_progress_game) { create(:game, competition: competition, result: "in_progress") }
  let_it_be(:finished_game) { create(:game, competition: competition, result: "peace_victory") }

  describe "#subscribed" do
    context "for an in-progress game (public broadcast)" do
      before { stub_connection(current_user: nil) }

      it "subscribes anonymously" do
        subscribe(game_id: in_progress_game.id)

        expect(subscription).to be_confirmed
        expect(subscription).to have_stream_for(in_progress_game)
      end
    end

    context "for a finished game" do
      context "with no user" do
        before { stub_connection(current_user: nil) }

        it "rejects subscription" do
          subscribe(game_id: finished_game.id)

          expect(subscription).to be_rejected
        end
      end

      context "with a non-judge user" do
        let_it_be(:regular_user) { create(:user) }

        before { stub_connection(current_user: regular_user) }

        it "rejects subscription" do
          subscribe(game_id: finished_game.id)

          expect(subscription).to be_rejected
        end
      end

      context "with a judge user" do
        let_it_be(:judge) { create(:user, :judge) }

        before { stub_connection(current_user: judge) }

        it "subscribes to a stream for the game" do
          subscribe(game_id: finished_game.id)

          expect(subscription).to be_confirmed
          expect(subscription).to have_stream_for(finished_game)
        end
      end
    end

    context "when game_id is missing" do
      before { stub_connection(current_user: nil) }

      it "rejects subscription" do
        subscribe(game_id: nil)

        expect(subscription).to be_rejected
      end
    end

    context "when game is not found" do
      before { stub_connection(current_user: nil) }

      it "rejects subscription" do
        subscribe(game_id: -1)

        expect(subscription).to be_rejected
      end
    end
  end
end
