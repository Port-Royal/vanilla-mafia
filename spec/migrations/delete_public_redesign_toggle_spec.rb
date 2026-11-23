# frozen_string_literal: true

require "rails_helper"
require_relative "../../db/migrate/20261123120000_delete_public_redesign_toggle"

RSpec.describe DeletePublicRedesignToggle do
  let(:migration) { described_class.new }

  describe "#up" do
    let_it_be(:other_toggle) { create(:feature_toggle, key: "live_protocol", enabled: true) }

    before do
      # The key is no longer valid, so the row is written the way old data looks.
      FeatureToggle.insert_all!([ { key: "public_redesign", enabled: true, value: "everyone",
                                    created_at: Time.current, updated_at: Time.current } ])
      ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
    end

    it "deletes the public redesign toggle" do
      expect(FeatureToggle.exists?(key: "public_redesign")).to be false
    end

    it "keeps the other toggles" do
      expect(FeatureToggle.exists?(other_toggle.id)).to be true
    end
  end

  describe "#down" do
    it "refuses to roll back" do
      expect { ActiveRecord::Migration.suppress_messages { migration.migrate(:down) } }.to raise_error(ActiveRecord::IrreversibleMigration)
    end
  end
end
