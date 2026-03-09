FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    locale { "ru" }

    trait :admin do
      role { "admin" }
    end

    trait :judge do
      role { "judge" }
    end

    trait :editor do
      role { "editor" }
    end
  end
end
