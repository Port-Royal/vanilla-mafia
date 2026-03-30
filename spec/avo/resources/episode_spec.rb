# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::Episode do
  subject(:resource) { described_class.new(record: episode, view: :edit) }

  let_it_be(:episode) { create(:episode) }

  before { resource.detect_fields }

  let(:items) { resource.items }

  describe "fields" do
    it "includes the image field" do
      field = items.find { |f| f.id == :image }

      expect(field).to be_a(Avo::Fields::FileField)
    end
  end
end
