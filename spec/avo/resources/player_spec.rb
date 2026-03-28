# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::Player do
  subject(:resource) { described_class.new(record: player, view: :index) }

  let_it_be(:player) { create(:player) }

  before { resource.detect_fields }

  describe "fields" do
    it "does not include position" do
      expect(resource.items.map(&:id)).not_to include(:position)
    end
  end
end
