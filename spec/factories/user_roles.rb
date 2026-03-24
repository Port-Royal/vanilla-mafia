FactoryBot.define do
  factory :user_role do
    user
    role { "user" }

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
