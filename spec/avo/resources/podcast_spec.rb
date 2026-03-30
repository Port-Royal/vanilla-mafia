# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::Podcast do
  subject(:resource) { described_class.new(record: podcast, view: :edit) }

  let_it_be(:podcast) { create(:podcast) }

  before { resource.detect_fields }

  let(:items) { resource.items }

  describe "fields" do
    it "exposes all editable podcast metadata fields" do
      expect(items.map(&:id)).to eq(%i[id title author description language category cover])
    end
  end

  describe "navigation_label" do
    it "is grouped under Podcast" do
      expect(described_class.navigation_label).to eq("Podcast: Settings")
    end
  end
end
