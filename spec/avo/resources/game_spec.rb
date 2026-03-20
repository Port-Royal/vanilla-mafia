# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::Game do
  subject(:resource) { described_class.new(record: game, view: :index) }

  let_it_be(:game) { create(:game) }

  before { resource.detect_fields }

  let(:items) { resource.items }

  describe "fields" do
    it "includes competition belongs_to as required" do
      field = items.find { |f| f.id == :competition }

      expect(field).to be_a(Avo::Fields::BelongsToField)
      expect(field.required).to be(true)
    end

    it "does not include season" do
      expect(items.map(&:id)).not_to include(:season)
    end

    it "does not include series" do
      expect(items.map(&:id)).not_to include(:series)
    end
  end
end
