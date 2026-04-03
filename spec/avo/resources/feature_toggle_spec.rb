# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::FeatureToggle do
  subject(:resource) { described_class.new(record: toggle, view: view) }

  let_it_be(:toggle) { create(:feature_toggle, key: "home_hero", value: "banner.jpg") }

  before { resource.detect_fields }

  describe "value field" do
    context "on index view" do
      let(:view) { :index }

      it "is present" do
        field = resource.get_field(:toggle_value)
        expect(field).to be_present
      end

      it "reads from the value attribute" do
        field = resource.get_field(:toggle_value)
        expect(field.value).to eq("banner.jpg")
      end
    end

    context "on edit view" do
      let(:view) { :edit }

      it "is present" do
        field = resource.get_field(:toggle_value)
        expect(field).to be_present
      end
    end
  end
end
