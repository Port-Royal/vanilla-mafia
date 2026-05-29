# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avo::Resources::Player do
  subject(:resource) { described_class.new(record: player, view: :index) }

  let_it_be(:player) { create(:player) }

  before { resource.detect_fields }

  describe "fields" do
    it "does not include position" do
      expect(resource.items.map(&:id)).not_to include(:position)
    end
  end

  describe "search query" do
    let_it_be(:cyrillic_player) { create(:player, name: "Иван") }
    let_it_be(:ascii_player) { create(:player, name: "Alexei") }

    def run_search(q)
      Avo::ExecutionContext.new(
        target: described_class.search[:query],
        query: Player.all,
        params: { q: q }
      ).handle
    end

    it "executes without raising a SQLite syntax error" do
      expect { run_search("anything") }.not_to raise_error
    end

    it "matches ASCII names case-insensitively" do
      expect(run_search("ALEX")).to contain_exactly(ascii_player)
    end

    it "matches Cyrillic names by exact-case substring" do
      expect(run_search("Иван")).to contain_exactly(cyrillic_player)
    end
  end
end
