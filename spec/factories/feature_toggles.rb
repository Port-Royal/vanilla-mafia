FactoryBot.define do
  factory :feature_toggle do
    key { "require_approval" }
    enabled { false }
  end
end
