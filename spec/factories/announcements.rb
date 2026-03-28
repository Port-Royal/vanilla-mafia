FactoryBot.define do
  factory :announcement do
    sequence(:version) { |n| "1.0.#{n}" }
    message { "New feature available" }
  end
end
