require "rails_helper"

RSpec.describe "Seeds" do
  before do
    load Rails.root.join("db/seeds.rb")
  end

  it "seeds all feature toggles defined in FeatureToggle::KEYS" do
    expect(FeatureToggle.pluck(:key)).to match_array(FeatureToggle::KEYS)
  end

  it "seeds sample announcements" do
    expect(Announcement.count).to be >= 3
  end

  it "seeds announcements with different grant codes" do
    grant_codes = Announcement.pluck(:grant_code).uniq
    expect(grant_codes).to include(nil)
    expect(grant_codes.compact).not_to be_empty
  end

  it "is idempotent for announcements" do
    initial_count = Announcement.count

    expect {
      load Rails.root.join("db/seeds.rb")
    }.not_to change(Announcement, :count)

    expect(Announcement.count).to eq(initial_count)
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
