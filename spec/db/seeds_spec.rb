require "rails_helper"

RSpec.describe "Seeds" do
  before do
    load Rails.root.join("db/seeds.rb")
  end

  it "seeds all feature toggles defined in FeatureToggle::KEYS" do
    expect(FeatureToggle.pluck(:key)).to match_array(FeatureToggle::KEYS)
  end

  it "is idempotent for feature toggles" do
    initial_count = FeatureToggle.count
    initial_keys  = FeatureToggle.pluck(:key)

    expect {
      load Rails.root.join("db/seeds.rb")
    }.not_to change(FeatureToggle, :count)

    expect(FeatureToggle.pluck(:key)).to match_array(initial_keys)
    expect(FeatureToggle.pluck(:key)).to match_array(FeatureToggle::KEYS)
  end
end
