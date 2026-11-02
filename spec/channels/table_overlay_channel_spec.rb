require "rails_helper"

RSpec.describe TableOverlayChannel do
  before { stub_connection(current_user: nil) }

  describe "#subscribed" do
    context "with a table number" do
      before { subscribe(table: 2) }

      it "streams the table anonymously" do
        expect([ subscription.confirmed?, subscription.streams ]).to eq([ true, [ "table_overlay:2" ] ])
      end
    end

    context "with a table number given as text" do
      before { subscribe(table: "3") }

      it "streams the table" do
        expect(subscription).to have_stream_from("table_overlay:3")
      end
    end

    context "with a table number of two digits" do
      before { subscribe(table: 12) }

      it "streams the table" do
        expect(subscription).to have_stream_from("table_overlay:12")
      end
    end

    {
      "zero" => 0,
      "a leading zero" => "01",
      "trailing text" => "2a",
      "text" => "abc",
      "no table" => nil
    }.each do |label, table|
      context "with #{label}" do
        before { subscribe(table:) }

        it "rejects without streaming" do
          expect([ subscription.rejected?, subscription.streams ]).to eq([ true, [] ])
        end
      end
    end
  end

  describe "#subscribed without parameters" do
    it "rejects" do
      subscribe
      expect(subscription).to be_rejected
    end
  end

  describe ".broadcast_current" do
    context "with a current game at the table" do
      let_it_be(:game) { create(:game, table_number: 4, played_on: Date.current) }

      it "announces its id" do
        expect { described_class.broadcast_current(4) }
          .to have_broadcasted_to("table_overlay:4").with(game_id: game.id)
      end
    end

    context "with no game at the table" do
      it "announces an empty table" do
        expect { described_class.broadcast_current(5) }
          .to have_broadcasted_to("table_overlay:5").with(game_id: nil)
      end
    end
  end
end
