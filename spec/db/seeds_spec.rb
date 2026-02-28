require "rails_helper"

RSpec.describe "Seeds" do
  before do
    load Rails.root.join("db/seeds.rb")
  end

  it "seeds all feature toggles defined in FeatureToggle::KEYS" do
    expect(FeatureToggle.pluck(:key)).to match_array(FeatureToggle::KEYS)
  end
end
