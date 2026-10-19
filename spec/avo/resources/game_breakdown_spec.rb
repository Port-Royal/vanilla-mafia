# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::GameBreakdown do
  subject(:resource) { described_class.new(record: breakdown, view: :show) }

  let_it_be(:breakdown) { create(:game_breakdown) }

  before { resource.detect_fields }

  it "exposes the mafia acquaintance as a textarea" do
    expect(resource.items.find { |field| field.id == :mafia_acquaintance }).to be_a(Avo::Fields::TextareaField)
  end
end
