# frozen_string_literal: true

require "rails_helper"
require_relative "../../db/migrate/20261123120000_delete_retired_feature_toggles"

RSpec.describe DeleteRetiredFeatureToggles do
  let(:migration) { described_class.new }

  describe "#up" do
    let_it_be(:other_toggle) { create(:feature_toggle, key: "live_protocol", enabled: true) }
    let(:retired_keys) { %w[public_redesign home_hero home_hall_of_fame home_stats home_documents home_whats_new] }

    before do
      # The keys are no longer valid, so the rows are written the way old data looks.
      FeatureToggle.insert_all!(retired_keys.map do |key|
        { key:, enabled: true, value: nil, created_at: Time.current, updated_at: Time.current }
      end)
      ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
    end

    it "deletes every retired toggle" do
      expect(FeatureToggle.where(key: retired_keys)).to be_empty
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
