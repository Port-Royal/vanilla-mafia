FactoryBot.define do
  factory :document do
    sequence(:title) { |n| "Document #{n}" }

    trait :published do
      published { true }
    end
  end
end
