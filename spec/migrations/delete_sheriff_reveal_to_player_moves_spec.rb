# frozen_string_literal: true

require "rails_helper"
require_relative "../../db/migrate/20261019040000_delete_sheriff_reveal_to_player_moves"

RSpec.describe DeleteSheriffRevealToPlayerMoves do
  let(:migration) { described_class.new }

  describe "#up" do
    let_it_be(:speech) { create(:breakdown_speech) }
    let_it_be(:hidden_reveal) { create(:breakdown_move, :nomination, breakdown_speech: speech, target_seat: 3) }
    let_it_be(:table_reveal) { create(:breakdown_move, :sheriff_reveal_table, breakdown_speech: speech) }

    before do
      # The kind is no longer in the enum, so the row is set up the way old data looks.
      ActiveRecord::Base.connection.execute(
        "UPDATE breakdown_moves SET kind = 'sheriff_reveal_to_player' WHERE id = #{hidden_reveal.id}"
      )
      ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
    end

    it "deletes the moves of the removed kind" do
      expect(BreakdownMove.exists?(hidden_reveal.id)).to be false
    end

    it "keeps the other moves" do
      expect(BreakdownMove.exists?(table_reveal.id)).to be true
    end
  end

  describe "#down" do
    it "refuses to roll back" do
      expect { ActiveRecord::Migration.suppress_messages { migration.migrate(:down) } }.to raise_error(ActiveRecord::IrreversibleMigration)
    end
  end
end
