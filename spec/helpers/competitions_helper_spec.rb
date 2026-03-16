require "rails_helper"

RSpec.describe CompetitionsHelper do
  describe "#win_percentage" do
    let(:player) { Data.define(:wins_count, :games_count).new(wins_count: wins, games_count: games) }

    context "when player has no games" do
      let(:wins) { 0 }
      let(:games) { 0 }

      it "returns 0.0" do
        expect(helper.win_percentage(player)).to eq(0.0)
      end
    end

    context "when player has won all games" do
      let(:wins) { 3 }
      let(:games) { 3 }

      it "returns 100.0" do
        expect(helper.win_percentage(player)).to eq(100.0)
      end
    end

    context "when player has partial wins" do
      let(:wins) { 1 }
      let(:games) { 3 }

      it "returns the rounded percentage" do
        expect(helper.win_percentage(player)).to eq(33.3)
      end
    end
  end
end
