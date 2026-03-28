# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::User do
  subject(:resource) { described_class.new(record: user, view: :show) }

  let_it_be(:user) { create(:user) }

  describe "actions" do
    it "includes ResetPassword action" do
      action_classes = resource.get_actions.map { |a| a[:class] }
      expect(action_classes).to include(Avo::Actions::ResetPassword)
    end
  end
end
