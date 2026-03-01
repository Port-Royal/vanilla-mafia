require "rails_helper"

RSpec.describe FeatureToggle, type: :model do
  describe "validations" do
    subject { build(:feature_toggle) }

    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_uniqueness_of(:key) }
    it { is_expected.to validate_inclusion_of(:key).in_array(described_class::KEYS) }
  end

  describe ".enabled?" do
    context "when toggle exists and is enabled" do
      let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: true) }

      it "returns true" do
        expect(described_class.enabled?(:require_approval)).to be true
      end
    end

    context "when toggle exists and is disabled" do
      let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: false) }

      it "returns false" do
        expect(described_class.enabled?(:require_approval)).to be false
      end
    end

    context "when toggle does not exist" do
      it "returns false" do
        expect(described_class.enabled?(:require_approval)).to be false
      end
    end

    it "uses Rails.cache.fetch with the correct key and TTL" do
      cache = instance_double(ActiveSupport::Cache::Store)
      allow(Rails).to receive(:cache).and_return(cache)
      allow(cache).to receive(:fetch)
        .with("feature_toggle/require_approval", expires_in: 5.minutes)
        .and_return(false)

      result = described_class.enabled?(:require_approval)

      expect(cache).to have_received(:fetch)
        .with("feature_toggle/require_approval", expires_in: 5.minutes)
      expect(result).to be false
    end
  end

  describe ".cache_key_for" do
    it "returns a namespaced cache key" do
      expect(described_class.cache_key_for("require_approval")).to eq("feature_toggle/require_approval")
    end
  end

  describe "cache invalidation" do
    let!(:toggle) { create(:feature_toggle, key: "require_approval", enabled: true) }

    it "clears the cache on commit" do
      cache = instance_double(ActiveSupport::Cache::Store)
      allow(Rails).to receive(:cache).and_return(cache)
      allow(cache).to receive(:delete)

      toggle.run_callbacks(:commit)

      expect(cache).to have_received(:delete).with("feature_toggle/require_approval")
    end
  end
end
