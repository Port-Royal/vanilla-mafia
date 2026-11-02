require "rails_helper"

RSpec.describe GameProtocolEvent do
  let_it_be(:game) { create(:game) }

  let(:event) { build(:game_protocol_event, game:, **attrs) }
  let(:attrs) { {} }

  describe "associations" do
    it { is_expected.to belong_to(:game) }
  end

  describe "validations" do
    subject { create(:game_protocol_event, game:) }

    it { is_expected.to validate_presence_of(:client_id) }
    it { is_expected.to validate_presence_of(:action_id) }
    it { is_expected.to validate_uniqueness_of(:client_id).scoped_to(:game_id) }
    it { is_expected.to validate_uniqueness_of(:position).scoped_to(:game_id) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
    it { is_expected.to validate_inclusion_of(:phase).in_array(described_class::PHASES) }
    it { is_expected.to validate_numericality_of(:position).only_integer }
    it { is_expected.to validate_numericality_of(:day_number).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:actor_seat).only_integer.is_in(1..10).allow_nil }
  end

  it "knows every kind of the protocol" do
    expect(described_class::KINDS).to eq(%w[
      roles deal speaker suspect red team check_request nominate nomination_cancelled note vote round_closed
      round_cancelled vote_skipped leaving_closed shot miss_shot don_check sheriff_check night_closed best_move will foul tech
      sanction_cancelled player_left player_restored game_finished
    ])
  end

  it "knows every phase" do
    expect(described_class::PHASES).to eq(%w[deal day night])
  end

  describe "the field an error lands on" do
    before { event.valid? }

    {
      "target_seats outside the seats" => [ { target_seats: [ 11 ] }, [ :target_seats ] ],
      "metadata that is not a hash" => [ { metadata: "text" }, [ :metadata ] ],
      "roles without a roles hash" => [ { kind: "roles", metadata: { "roles" => "don" } }, [ :metadata ] ],
      "player_left with a bad reason" => [ { kind: "player_left", target_seats: [ 2 ], metadata: { "reason" => "bored" } }, [ :metadata ] ],
      "player_left naming nobody" => [ { kind: "player_left", metadata: { "reason" => "killed" } }, [ :target_seats ] ],
      "player_restored naming nobody" => [ { kind: "player_restored" }, [ :target_seats ] ],
      "game_finished with a bad result" => [ { kind: "game_finished", metadata: { "result" => "in_progress" } }, [ :metadata ] ]
    }.each do |name, (given, fields)|
      context "with #{name}" do
        let(:attrs) { given }

        it "names #{fields.join(', ')}" do
          expect(event.errors.attribute_names).to eq(fields)
        end
      end
    end
  end

  describe "target_seats" do
    [ [ [ 0 ], false ], [ [ 11 ], false ], [ [ "3" ], false ], [ [ 1, 10 ], true ], [ [], true ], [ "3", false ] ].each do |seats, valid|
      context "when #{seats.inspect}" do
        let(:attrs) { { target_seats: seats } }

        it "is #{valid ? 'valid' : 'invalid'}" do
          expect(event.valid?).to be(valid)
        end
      end
    end

    %w[player_left player_restored].each do |kind|
      context "when #{kind} names nobody" do
        let(:attrs) { { kind:, target_seats: [], metadata: { "reason" => "killed" } } }

        it "is invalid" do
          expect(event).not_to be_valid
        end
      end
    end
  end

  describe "metadata" do
    [ "text", [ 1 ], 5 ].each do |value|
      context "when it is #{value.inspect}" do
        let(:attrs) { { metadata: value } }

        it "is invalid" do
          expect(event).not_to be_valid
        end
      end
    end

    context "when an outcome kind has an array for metadata" do
      let(:attrs) { { kind: "roles", metadata: [ 1 ] } }

      it "is invalid without raising" do
        expect(event).not_to be_valid
      end
    end

    context "when it is a hash" do
      let(:attrs) { { metadata: { "any" => "thing" } } }

      it "is valid" do
        expect(event).to be_valid
      end
    end

    { "killed" => true, "voted" => true, "removed" => true, "bored" => false, nil => false }.each do |reason, valid|
      context "when player_left has reason #{reason.inspect}" do
        let(:attrs) { { kind: "player_left", target_seats: [ 2 ], metadata: { "reason" => reason } } }

        it "is #{valid ? 'valid' : 'invalid'}" do
          expect(event.valid?).to be(valid)
        end
      end
    end

    { "peace_victory" => true, "mafia_victory" => true, "draw" => true, "in_progress" => false, nil => false }.each do |result, valid|
      context "when game_finished has result #{result.inspect}" do
        let(:attrs) { { kind: "game_finished", metadata: { "result" => result } } }

        it "is #{valid ? 'valid' : 'invalid'}" do
          expect(event.valid?).to be(valid)
        end
      end
    end

    context "when roles carries no roles hash" do
      let(:attrs) { { kind: "roles", metadata: { "roles" => "don" } } }

      it "is invalid" do
        expect(event).not_to be_valid
      end
    end

    context "when roles carries a roles hash" do
      let(:attrs) { { kind: "roles", metadata: { "roles" => { "1" => "don" } } } }

      it "is valid" do
        expect(event).to be_valid
      end
    end
  end

  describe ".removable_group?" do
    let!(:first) { create(:game_protocol_event, game:, position: 1, action_id: "a", kind:, day_number: 2) }
    let!(:last) { create(:game_protocol_event, game:, position: 2, action_id: "b", kind: "speaker", day_number: 2) }
    let(:kind) { "foul" }

    it "allows the last action of any kind" do
      expect(described_class.removable_group?([ last ])).to be(true)
    end

    it "allows a group that reaches the last position" do
      expect(described_class.removable_group?([ first, last ])).to be(true)
    end

    it "refuses a middle action of another kind" do
      expect(described_class.removable_group?([ first ])).to be(false)
    end

    %w[suspect red team check_request note will best_move].each do |deletable|
      context "when a middle action is #{deletable}" do
        let(:kind) { deletable }

        it "allows it" do
          expect(described_class.removable_group?([ first ])).to be(true)
        end
      end
    end

    context "when a middle action is a nomination" do
      let(:kind) { "nominate" }

      it "allows it while the day has no votes" do
        expect(described_class.removable_group?([ first ])).to be(true)
      end

      context "with a vote that day" do
        before { create(:game_protocol_event, game:, position: 3, kind: "vote", day_number: 2) }

        it "refuses it" do
          expect(described_class.removable_group?([ first ])).to be(false)
        end
      end

      context "with a vote on another day" do
        before { create(:game_protocol_event, game:, position: 3, kind: "vote", day_number: 1) }

        it "allows it" do
          expect(described_class.removable_group?([ first ])).to be(true)
        end
      end

      context "with a vote that day in another game" do
        before { create(:game_protocol_event, position: 3, kind: "vote", day_number: 2) }

        it "allows it" do
          expect(described_class.removable_group?([ first ])).to be(true)
        end
      end
    end

    context "when only part of a middle group may be deleted" do
      let(:kind) { "note" }
      let(:other) { create(:game_protocol_event, game:, position: 3, action_id: "c", kind: "foul") }

      before { create(:game_protocol_event, game:, position: 4, kind: "speaker") }

      it "refuses the group" do
        expect(described_class.removable_group?([ first, other ])).to be(false)
      end
    end
  end

  describe "game association" do
    let!(:saved) { create(:game_protocol_event) }

    it "is destroyed with the game" do
      expect { saved.game.destroy! }.to change(described_class, :count).by(-1)
    end
  end
end
