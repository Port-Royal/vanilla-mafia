# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::PlayerClaim do
  subject(:resource) { described_class.new(record: player_claim, view: :index) }

  let_it_be(:player_claim) { create(:player_claim) }

  before { resource.detect_fields }

  describe "fields" do
    it "does not include created_at" do
      expect(resource.items.map(&:id)).not_to include(:created_at)
    end

    it "does not include updated_at" do
      expect(resource.items.map(&:id)).not_to include(:updated_at)
    end
  end
end
