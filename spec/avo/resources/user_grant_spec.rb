# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::UserGrant do
  subject(:resource) { described_class.new(record: user_grant, view: :edit) }

  let_it_be(:user_grant) { create(:user_grant) }

  before { resource.detect_fields }

  describe "fields" do
    it "includes user belongs_to" do
      field = resource.items.find { |f| f.id == :user }

      expect(field).to be_a(Avo::Fields::BelongsToField)
    end

    it "includes grant belongs_to" do
      field = resource.items.find { |f| f.id == :grant }

      expect(field).to be_a(Avo::Fields::BelongsToField)
    end
  end
end
