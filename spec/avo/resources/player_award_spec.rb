# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::PlayerAward do
  subject(:resource) { described_class.new(record: player_award, view: :index) }

  let_it_be(:player_award) { create(:player_award) }

  before { resource.detect_fields }

  let(:items) { resource.items }

  describe "fields" do
    it "includes competition belongs_to" do
      field = items.find { |f| f.id == :competition }

      expect(field).to be_a(Avo::Fields::BelongsToField)
    end

    it "makes player searchable" do
      field = items.find { |f| f.id == :player }

      expect(field.instance_variable_get(:@searchable)).to be(true)
    end

    it "does not include season" do
      expect(items.map(&:id)).not_to include(:season)
    end
  end
end
