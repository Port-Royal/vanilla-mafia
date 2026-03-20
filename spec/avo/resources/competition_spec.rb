# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::Competition do
  subject(:resource) { described_class.new(record: competition, view: :index) }

  let_it_be(:competition) { create(:competition, :season) }

  before { resource.detect_fields }

  let(:items) { resource.items }

  describe "fields" do
    it "includes name as text" do
      field = items.find { |f| f.id == :name }

      expect(field).to be_a(Avo::Fields::TextField)
    end

    it "includes slug as text" do
      field = items.find { |f| f.id == :slug }

      expect(field).to be_a(Avo::Fields::TextField)
    end

    it "includes kind as select" do
      field = items.find { |f| f.id == :kind }

      expect(field).to be_a(Avo::Fields::SelectField)
    end

    it "includes position as number" do
      field = items.find { |f| f.id == :position }

      expect(field).to be_a(Avo::Fields::NumberField)
    end

    it "includes parent as optional belongs_to" do
      field = items.find { |f| f.id == :parent }

      expect(field).to be_a(Avo::Fields::BelongsToField)
      expect(field.required).to be(false)
    end

    it "includes started_on as date" do
      field = items.find { |f| f.id == :started_on }

      expect(field).to be_a(Avo::Fields::DateField)
    end

    it "includes ended_on as date" do
      field = items.find { |f| f.id == :ended_on }

      expect(field).to be_a(Avo::Fields::DateField)
    end

    it "includes featured as boolean" do
      field = items.find { |f| f.id == :featured }

      expect(field).to be_a(Avo::Fields::BooleanField)
    end

    it "includes children as has_many" do
      field = items.find { |f| f.id == :children }

      expect(field).to be_a(Avo::Fields::HasManyField)
    end

    it "includes games as has_many" do
      field = items.find { |f| f.id == :games }

      expect(field).to be_a(Avo::Fields::HasManyField)
    end
  end
end
