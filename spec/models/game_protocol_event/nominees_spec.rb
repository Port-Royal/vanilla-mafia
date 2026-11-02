require "rails_helper"

RSpec.describe GameProtocolEvent::Nominees do
  let(:event) do
    lambda do |kind, phase: "day", actor: nil, targets: [], metadata: {}|
      GameProtocolEvent.new(kind:, phase:, day_number: 0, actor_seat: actor, target_seats: targets, metadata:)
    end
  end
  let(:nominate) { ->(by, seat) { event.call("nominate", actor: by, targets: [ seat ]) } }
  let(:voted_out) { ->(seat) { event.call("player_left", targets: [ seat ], metadata: { "reason" => "voted" }) } }
  let(:to_vote) { event.call("speaker") }
  let(:nominees) { described_class.call(events) }

  context "with no events" do
    let(:events) { [] }

    it "is empty" do
      expect(nominees).to eq([])
    end
  end

  context "with nominations" do
    let(:events) { [ nominate.call(1, 5), nominate.call(2, 3) ] }

    it "keeps the order of nomination" do
      expect(nominees).to eq([ 5, 3 ])
    end
  end

  context "with a cancelled nomination" do
    let(:events) { [ nominate.call(1, 5), nominate.call(2, 3), event.call("nomination_cancelled", targets: [ 5 ]) ] }

    it "drops it" do
      expect(nominees).to eq([ 3 ])
    end
  end

  context "with a candidate removed during the speeches" do
    let(:events) { [ nominate.call(1, 5), nominate.call(2, 3), event.call("player_left", targets: [ 5 ], metadata: { "reason" => "removed" }) ] }

    it "drops the candidate" do
      expect(nominees).to eq([ 3 ])
    end
  end

  context "with a candidate removed during the vote" do
    let(:events) { [ nominate.call(1, 5), nominate.call(2, 3), to_vote, event.call("player_left", targets: [ 5 ], metadata: { "reason" => "removed" }) ] }

    it "keeps the candidate on the vote" do
      expect(nominees).to eq([ 5, 3 ])
    end
  end

  context "with somebody else removed during the speeches" do
    let(:events) { [ nominate.call(1, 5), event.call("player_left", targets: [ 9 ], metadata: { "reason" => "removed" }) ] }

    it "keeps the candidates" do
      expect(nominees).to eq([ 5 ])
    end
  end

  context "during the vote" do
    let(:events) { [ nominate.call(1, 5), nominate.call(2, 3), to_vote, event.call("vote", targets: [ 5 ]) ] }

    it "keeps the candidates" do
      expect(nominees).to eq([ 5, 3 ])
    end
  end

  %w[vote_skipped round_cancelled].each do |kind|
    context "with #{kind}" do
      let(:events) { [ nominate.call(1, 5), to_vote, event.call(kind) ] }

      it "is empty at the start of the night" do
        expect(nominees).to eq([])
      end
    end
  end

  context "with a round closed with nobody leaving" do
    let(:events) { [ nominate.call(1, 5), nominate.call(2, 3), to_vote, event.call("round_closed", metadata: { "outcome" => "none" }) ] }

    it "is empty" do
      expect(nominees).to eq([])
    end
  end

  context "with a repeat" do
    let(:events) { [ nominate.call(1, 5), nominate.call(2, 3), to_vote, event.call("round_closed", metadata: { "outcome" => "repeat" }) ] }

    it "keeps the candidates" do
      expect(nominees).to eq([ 5, 3 ])
    end
  end

  context "during the leaving speech after the vote" do
    let(:events) { [ nominate.call(1, 5), to_vote, event.call("round_closed", metadata: { "outcome" => "leave" }), voted_out.call(5) ] }

    it "keeps the candidates" do
      expect(nominees).to eq([ 5 ])
    end
  end

  context "after the last leaving speech" do
    let(:events) { [ nominate.call(1, 5), to_vote, event.call("round_closed", metadata: { "outcome" => "leave" }), voted_out.call(5), event.call("leaving_closed", actor: 5) ] }

    it "is empty" do
      expect(nominees).to eq([])
    end
  end

  context "between two leaving speeches" do
    let(:events) do
      [ nominate.call(1, 5), nominate.call(2, 6), to_vote, event.call("round_closed", metadata: { "outcome" => "leave" }),
        voted_out.call(5), voted_out.call(6), event.call("leaving_closed", actor: 5) ]
    end

    it "keeps the candidates" do
      expect(nominees).to eq([ 5, 6 ])
    end
  end

  context "with the leaving speech after a night" do
    let(:events) { [ event.call("night_closed", phase: "night"), nominate.call(1, 5), event.call("leaving_closed", actor: 9) ] }

    it "keeps the new day's candidates" do
      expect(nominees).to eq([ 5 ])
    end
  end

  context "with a vote after a morning leaving speech" do
    let(:events) do
      [ event.call("night_closed", phase: "night"), event.call("leaving_closed", actor: 9), nominate.call(1, 5), to_vote,
        event.call("round_closed", metadata: { "outcome" => "leave" }), voted_out.call(5), event.call("leaving_closed", actor: 5) ]
    end

    it "is empty after that vote's leaving speech" do
      expect(nominees).to eq([])
    end
  end

  context "with a clicked speaker before a removal" do
    let(:events) { [ nominate.call(1, 5), event.call("speaker", actor: 3), event.call("player_left", targets: [ 5 ], metadata: { "reason" => "removed" }) ] }

    it "still drops the candidate" do
      expect(nominees).to eq([])
    end
  end

  context "with any event of the night" do
    let(:events) { [ nominate.call(1, 5), event.call("foul", phase: "night", targets: [ 2 ]) ] }

    it "is empty" do
      expect(nominees).to eq([])
    end
  end

  context "on the next day" do
    let(:events) { [ nominate.call(1, 5), event.call("night_closed", phase: "night"), nominate.call(2, 7) ] }

    it "has only that day's candidates" do
      expect(nominees).to eq([ 7 ])
    end
  end

  context "with a removal on a new day before any vote" do
    let(:events) { [ nominate.call(1, 5), to_vote, event.call("vote_skipped"), event.call("night_closed", phase: "night"), nominate.call(2, 7), event.call("player_left", targets: [ 7 ], metadata: { "reason" => "removed" }) ] }

    it "drops the candidate again" do
      expect(nominees).to eq([])
    end
  end
end
