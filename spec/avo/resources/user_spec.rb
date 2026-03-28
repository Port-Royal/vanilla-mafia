# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::User do
  subject(:resource) { described_class.new(record: user, view: :show) }

  let_it_be(:user) { create(:user) }

  describe "title" do
    it "uses display_name as title" do
      expect(described_class.title).to eq(:display_name)
    end
  end

  describe "search" do
    it "is configured" do
      expect(described_class.search).to be_a(Hash)
      expect(described_class.search[:query]).to be_present
    end
  end

  describe "actions" do
    it "includes ResetPassword action" do
      action_classes = resource.get_actions.map { |a| a[:class] }
      expect(action_classes).to include(Avo::Actions::ResetPassword)
    end
  end
end
