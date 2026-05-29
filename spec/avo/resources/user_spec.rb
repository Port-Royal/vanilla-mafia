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

    context "query execution" do
      let_it_be(:by_email) { create(:user, email: "alex@example.com") }
      let_it_be(:player) { create(:player, name: "Maria") }
      let_it_be(:by_player_name) { create(:user, player: player) }

      def run_search(q)
        Avo::ExecutionContext.new(
          target: described_class.search[:query],
          query: User.all,
          params: { q: q }
        ).handle
      end

      it "executes without raising a SQLite syntax error" do
        expect { run_search("anything") }.not_to raise_error
      end

      it "matches by email case-insensitively" do
        expect(run_search("ALEX@EXAMPLE")).to include(by_email)
      end

      it "matches by linked player name case-insensitively" do
        expect(run_search("MARIA")).to include(by_player_name)
      end
    end
  end

  describe "actions" do
    it "includes ResetPassword action" do
      action_classes = resource.get_actions.map { |a| a[:class] }
      expect(action_classes).to include(Avo::Actions::ResetPassword)
    end
  end
end
