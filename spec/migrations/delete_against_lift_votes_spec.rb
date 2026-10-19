# frozen_string_literal: true

require "rails_helper"
require_relative "../../db/migrate/20261019060000_delete_against_lift_votes"

RSpec.describe DeleteAgainstLiftVotes do
  let(:migration) { described_class.new }

  describe "#up" do
    let_it_be(:lift) { create(:breakdown_vote_round, kind: "lift") }
    let_it_be(:against) { create(:breakdown_vote, :lift, breakdown_vote_round: lift, voter_seat: 1) }
    let_it_be(:supporter) { create(:breakdown_vote, :lift, breakdown_vote_round: lift, voter_seat: 2) }
    let_it_be(:candidate_vote) { create(:breakdown_vote, voter_seat: 3) }

    before do
      # «Против» is no longer a valid ballot, so the row is set up the way old data looks.
      against.update_column(:for_lift, false)
      ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
    end

    it "deletes the votes against the lift" do
      expect(BreakdownVote.exists?(against.id)).to be false
    end

    it "keeps the votes for the lift and the candidate votes" do
      expect(BreakdownVote.where(id: [ supporter.id, candidate_vote.id ]).count).to eq(2)
    end
  end

  describe "#down" do
    it "refuses to roll back" do
      expect { ActiveRecord::Migration.suppress_messages { migration.migrate(:down) } }.to raise_error(ActiveRecord::IrreversibleMigration)
    end
  end
end
