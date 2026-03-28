# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::Award do
  describe "index_query" do
    let_it_be(:staff_award) { create(:award, title: "Staff Award", staff: true, position: 1) }
    let_it_be(:player_award_b) { create(:award, title: "Player Award B", staff: false, position: 2) }
    let_it_be(:player_award_a) { create(:award, title: "Player Award A", staff: false, position: 1) }

    it "sorts non-staff awards before staff awards, then by position" do
      result = Avo::ExecutionContext.new(
        target: described_class.index_query,
        query: Award.all
      ).handle

      expect(result.pluck(:id)).to eq([ player_award_a.id, player_award_b.id, staff_award.id ])
    end
  end
end
