FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    locale { "ru" }

    trait :admin do
      after(:create) do |user|
        grant = Grant.find_or_create_by!(code: "admin")
        create(:user_grant, user: user, grant: grant)
      end
    end

    trait :judge do
      after(:create) do |user|
        grant = Grant.find_or_create_by!(code: "judge")
        create(:user_grant, user: user, grant: grant)
      end
    end

    trait :editor do
      after(:create) do |user|
        grant = Grant.find_or_create_by!(code: "editor")
        create(:user_grant, user: user, grant: grant)
      end
    end
  end
end
