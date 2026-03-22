require "rails_helper"

RSpec.describe GameProtocolChannel do
  let_it_be(:competition) { create(:competition, :series) }
  let_it_be(:game) { create(:game, game_number: 1, competition: competition) }

  before do
    stub_connection
  end

  describe "#subscribed" do
    it "subscribes to a stream for the game" do
      subscribe(game_id: game.id)

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_for(game)
    end

    it "rejects subscription when game_id is missing" do
      subscribe(game_id: nil)

      expect(subscription).to be_rejected
    end

    it "rejects subscription when game is not found" do
      subscribe(game_id: -1)

      expect(subscription).to be_rejected
    end
  end
end
