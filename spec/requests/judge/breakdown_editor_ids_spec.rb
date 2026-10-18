require "rails_helper"

# Turbo restores focus after a stream by element id, so a duplicate id in the editor sends the focus — and the
# scroll position — to the first block that shares it.
RSpec.describe "Judge::Breakdowns editor element ids" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin) }

  let!(:toggle) { create(:feature_toggle, key: "game_breakdown", enabled: true) }
  let(:breakdown) { create(:game_breakdown, author: admin, roles_mode: "open") }
  let(:zero_round) { breakdown.phases.find_by(position: 0) }
  let(:second_day) { day(2) }
  let(:duplicate_ids) { Nokogiri::HTML(response.body).css("[id]").map { |node| node["id"] }.tally.select { |_, count| count > 1 }.keys }

  before do
    sign_in admin
    assign_roles(mafia: [ 7, 8 ], don: 9, sheriff: 1)
    nominate(zero_round, 1, 4)
    nominate(zero_round, 2, 5)
    vote(zero_round, "main", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
    vote(zero_round, "revote", [ 1, 2, 3, 4, 5 ] => 4, [ 6, 7, 8, 9, 10 ] => 5)
    night(1)
    nominate(second_day, 3, 6)
    nominate(second_day, 4, 2)
    vote(second_day, "main", [ 1, 2, 3 ] => 6)
    night(3)
  end

  describe "GET /judge/breakdowns/:id/edit" do
    before { get edit_judge_breakdown_path(breakdown) }

    it "renders several vote rounds" do
      expect(response.body.scan(/name="votes\[1\]\[candidate_seat\]"/).size).to eq(3)
    end

    it "gives every element a unique id" do
      expect(duplicate_ids).to be_empty
    end
  end

  describe "PATCH /judge/breakdowns/:breakdown_id/vote_rounds/:id as a turbo stream" do
    let(:round) { second_day.vote_rounds.first }

    before do
      patch judge_breakdown_vote_round_path(breakdown, round),
            params: { votes: { "4" => { candidate_seat: "2" } } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "streams the phases with unique ids" do
      expect(duplicate_ids).to be_empty
    end
  end
end
